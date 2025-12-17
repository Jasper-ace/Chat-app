<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use App\Models\HomeownerJobOffer;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;

class JobOfferController extends Controller
{
    /**
     * List all job offers for the authenticated homeowner
     */
    public function index(Request $request)
    {
        $homeowner = $request->user();
        
        $jobOffers = HomeownerJobOffer::with(['category', 'services', 'photos'])
            ->where('homeowner_id', $homeowner->id)
            ->latest()
            ->get();

        // Add application count for each job
        $jobOffers = $jobOffers->map(function ($job) {
            $job->applications_count = \App\Models\JobApplication::where('job_offer_id', $job->id)->count();
            return $job;
        });

        return response()->json([
            'success' => true,
            'message' => 'Job offers fetched successfully.',
            'data' => $jobOffers,
        ]);
    }

    /**
     * Show a specific job offer
     */
    public function show(Request $request, $id)
    {
        $job = HomeownerJobOffer::with(['category', 'services', 'photos'])->findOrFail($id);

        if ($job->homeowner_id !== $request->user()->id) {
            abort(403, 'Unauthorized action.');
        }

        return response()->json(['success' => true, 'data' => $job]);
    }

    /**
     * Create a new job offer
     */
    public function store(Request $request)
    {
        try {
            $validated = $request->validate([
                'service_category_id' => 'required|exists:service_categories,id',
                'title' => 'required|string|max:255',
                'description' => 'nullable|string|max:300',
                'job_type' => 'required|in:standard,urgent,recurrent',
                'frequency' => 'nullable|required_if:job_type,recurrent|in:daily,weekly,monthly,quarterly,yearly,custom',
                'start_date' => 'nullable|required_if:job_type,recurrent|date',
                'end_date' => 'nullable|required_if:job_type,recurrent|date|after_or_equal:start_date',
                'preferred_date' => 'nullable|required_if:job_type,standard|date',
                'job_size' => 'required|in:small,medium,large',
                'address' => 'required|string|max:255',
                'latitude' => 'nullable|numeric',
                'longitude' => 'nullable|numeric',
                'services' => 'required|array|min:1',
                'services.*' => 'exists:services,id',
                'photos' => 'nullable|array|max:8',
                'photos.*' => 'string',
            ]);

            $homeowner = $request->user();

            $jobOffer = $homeowner->jobOffers()->create($validated);

            $jobOffer->services()->sync($validated['services']);

            if (!empty($validated['photos'])) {
                foreach ($validated['photos'] as $base64Image) {
                    $this->storeBase64Photo($jobOffer, $base64Image);
                }
            }

            return response()->json([
                'success' => true,
                'message' => 'Job offer created successfully.',
                'data' => $jobOffer->load(['services', 'photos']),
            ], 201);

        } catch (ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => $e->errors(),
            ], 422);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Unexpected error occurred.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Update a job offer
     */
    public function update(Request $request, $id)
    {
        try {
            $jobOffer = HomeownerJobOffer::findOrFail($id);

            if ($jobOffer->homeowner_id !== $request->user()->id) {
                abort(403, 'You do not have permission to update this job offer.');
            }

            $validated = $request->validate([
                'service_category_id' => 'sometimes|exists:service_categories,id',
                'title' => 'sometimes|string|max:255',
                'description' => 'nullable|string|max:300',
                'job_type' => 'sometimes|in:standard,urgent,recurrent',
                'frequency' => 'nullable|required_if:job_type,recurrent|in:daily,weekly,monthly,quarterly,yearly,custom',
                'start_date' => 'nullable|date',
                'end_date' => 'nullable|date|after_or_equal:start_date',
                'preferred_date' => 'nullable|required_if:job_type,standard|date',
                'job_size' => 'sometimes|in:small,medium,large',
                'address' => 'sometimes|string|max:255',
                'latitude' => 'nullable|numeric',
                'longitude' => 'nullable|numeric',
                'services' => 'sometimes|array',
                'services.*' => 'exists:services,id',
                'photos' => 'nullable|array|max:8',
                'photos.*' => 'string',
            ]);

            $jobOffer->update($validated);

            if (isset($validated['services'])) {
                $jobOffer->services()->sync($validated['services']);
            }

            if (!empty($validated['photos'])) {
                foreach ($validated['photos'] as $base64Image) {
                    $this->storeBase64Photo($jobOffer, $base64Image);
                }
            }

            return response()->json([
                'success' => true,
                'message' => 'Job offer updated successfully.',
                'data' => $jobOffer->load(['services', 'photos']),
            ]);

        } catch (ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => $e->errors(),
            ], 422);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Unexpected error occurred.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
    
    /**
     * Delete a job offer
     */
    public function destroy(Request $request, $id)
    {
        $jobOffer = HomeownerJobOffer::findOrFail($id);

        if ($jobOffer->homeowner_id !== $request->user()->id) {
            abort(403, 'You do not have permission to delete this job offer.');
        }

        // Check if job has accepted applications
        $acceptedApplications = \App\Models\JobApplication::where('job_offer_id', $id)
            ->where('status', 'accepted')
            ->count();

        if ($acceptedApplications > 0) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot delete job with accepted applications. Please contact the tradie directly if you need to cancel the work.',
            ], 400);
        }

        // Delete associated photos
        foreach ($jobOffer->photos as $photo) {
            Storage::disk('public')->delete($photo->file_path);
            $photo->delete();
        }

        // Delete associated job applications (only pending/rejected ones at this point)
        \App\Models\JobApplication::where('job_offer_id', $id)->delete();

        // Delete the job offer
        $jobOffer->delete();

        Log::info("Job offer {$id} deleted by homeowner {$request->user()->id}");

        return response()->json(['success' => true, 'message' => 'Job offer deleted successfully.']);
    }

    /**
     * Get available jobs for tradie based on their service category
     */
    public function getAvailableJobsForTradie(Request $request)
    {
        $tradie = $request->user();
        
        // Get tradie's service category ID
        $serviceCategoryId = $tradie->service_category_id;
        
        if (!$serviceCategoryId) {
            return response()->json([
                'success' => false,
                'message' => 'Tradie does not have a service category assigned.',
                'data' => []
            ], 400);
        }
        
        // Fetch job offers that match the tradie's service category and are open (not completed, cancelled, etc.)
        $jobOffers = HomeownerJobOffer::with(['category', 'services', 'photos', 'homeowner:id,first_name,last_name,email,phone'])
            ->where('service_category_id', $serviceCategoryId)
            ->where('status', 'open')
            ->latest()
            ->get();

        // Add application status for each job
        $jobOffers = $jobOffers->map(function ($job) use ($tradie) {
            $application = \App\Models\JobApplication::where('job_offer_id', $job->id)
                ->where('tradie_id', $tradie->id)
                ->first();
            
            $job->has_applied = $application !== null;
            $job->application_status = $application ? $application->status : null;
            
            return $job;
        });

        return response()->json([
            'success' => true,
            'message' => 'Available jobs fetched successfully.',
            'data' => $jobOffers,
        ]);
    }

    /**
     * Apply for a job
     */
    public function applyForJob(Request $request, $jobId)
    {
        try {
            $tradie = $request->user();
            
            // Check if job exists and is open
            $job = HomeownerJobOffer::findOrFail($jobId);
            
            if ($job->status !== 'open') {
                return response()->json([
                    'success' => false,
                    'message' => 'This job is no longer accepting applications.',
                ], 400);
            }
            
            // Check if tradie already applied
            $existingApplication = \App\Models\JobApplication::where('job_offer_id', $jobId)
                ->where('tradie_id', $tradie->id)
                ->first();
            
            if ($existingApplication) {
                return response()->json([
                    'success' => false,
                    'message' => 'You have already applied for this job.',
                ], 400);
            }
            
            // Create application
            $application = \App\Models\JobApplication::create([
                'job_offer_id' => $jobId,
                'tradie_id' => $tradie->id,
                'status' => 'pending',
                'cover_letter' => $request->input('cover_letter'),
                'proposed_price' => $request->input('proposed_price'),
            ]);
            
            return response()->json([
                'success' => true,
                'message' => 'Application submitted successfully.',
                'data' => $application,
            ], 201);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to submit application.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get applications for a specific job
     */
    public function getJobApplications(Request $request, $jobId)
    {
        try {
            $homeowner = $request->user();
            
            // Check if job belongs to the homeowner
            $job = HomeownerJobOffer::where('id', $jobId)
                ->where('homeowner_id', $homeowner->id)
                ->first();
            
            if (!$job) {
                return response()->json([
                    'success' => false,
                    'message' => 'Job not found or unauthorized.',
                ], 404);
            }
            
            // Get applications with tradie details
            $applications = \App\Models\JobApplication::with(['tradie'])
                ->where('job_offer_id', $jobId)
                ->orderBy('created_at', 'desc')
                ->get();
            
            return response()->json([
                'success' => true,
                'message' => 'Applications fetched successfully.',
                'data' => $applications,
            ]);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch applications.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Update application status (accept/reject)
     */
    public function updateApplicationStatus(Request $request, $jobId, $applicationId)
    {
        try {
            $validated = $request->validate([
                'status' => 'required|in:accepted,rejected',
            ]);

            $homeowner = $request->user();
            
            // Check if job belongs to the homeowner
            $job = HomeownerJobOffer::where('id', $jobId)
                ->where('homeowner_id', $homeowner->id)
                ->first();
            
            if (!$job) {
                return response()->json([
                    'success' => false,
                    'message' => 'Job not found or unauthorized.',
                ], 404);
            }
            
            // Get the application
            $application = \App\Models\JobApplication::with(['tradie'])
                ->where('id', $applicationId)
                ->where('job_offer_id', $jobId)
                ->first();
            
            if (!$application) {
                return response()->json([
                    'success' => false,
                    'message' => 'Application not found.',
                ], 404);
            }
            
            // Update application status
            $application->status = $validated['status'];
            $application->save();
            
            // If accepting this application, reject all other pending applications for this job
            if ($validated['status'] === 'accepted') {
                $otherApplications = \App\Models\JobApplication::with(['tradie'])
                    ->where('job_offer_id', $jobId)
                    ->where('id', '!=', $applicationId)
                    ->where('status', 'pending')
                    ->get();
                
                foreach ($otherApplications as $otherApp) {
                    $otherApp->status = 'rejected';
                    $otherApp->save();
                    
                    // Send rejection message to other tradies
                    $this->sendApplicationStatusMessage($homeowner, $otherApp->tradie, $job, 'rejected');
                }
                
                // Mark the job as completed since it's been filled
                $job->status = 'completed';
                $job->save();
                
                Log::info("Auto-rejected {$otherApplications->count()} other applications for job {$jobId} and marked job as completed");
            }
            
            // Note: Acceptance messages are sent through Flutter Firebase chat system
            // Only send rejection messages for auto-rejected applications
            if ($validated['status'] !== 'accepted') {
                $this->sendApplicationStatusMessage($homeowner, $application->tradie, $job, $validated['status']);
            }
            
            return response()->json([
                'success' => true,
                'message' => 'Application status updated successfully.',
                'data' => $application,
            ]);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update application status.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Send automated message to tradie about application status
     * Note: Acceptance messages are sent through Flutter Firebase chat system
     * This method is only used for auto-rejected applications
     */
    private function sendApplicationStatusMessage($homeowner, $tradie, $job, $status)
    {
        try {
            if ($status === 'rejected') {
                $message = "Thank you for your application for '{$job->title}'. Unfortunately, we have decided to go with another candidate. We appreciate your interest and encourage you to apply for future opportunities.";
                
                // Send through Firebase Realtime Database chat system
                $firebaseService = app(\App\Services\FirebaseRealtimeDatabaseService::class);
                
                $result = $firebaseService->sendMessage([
                    'sender_id' => $homeowner->id,
                    'receiver_id' => $tradie->id,
                    'sender_type' => 'homeowner',
                    'receiver_type' => 'tradie',
                    'message' => $message,
                ]);
                
                if ($result['success']) {
                    Log::info("Auto-rejection message sent to tradie {$tradie->id} for job {$job->id}");
                } else {
                    Log::error("Failed to send auto-rejection message: " . ($result['error'] ?? 'Unknown error'));
                }
            }
            
        } catch (\Exception $e) {
            // Log error but don't fail the main operation
            Log::error('Failed to send application status message: ' . $e->getMessage());
        }
    }

    /**
     * Helper : store a base64 image for a job offer
     */
    private function storeBase64Photo($jobOffer, $base64Image)
    {
        // Match base64 header
        if (preg_match('/^data:image\/(\w+);base64,/', $base64Image, $matches)) {
            $extension = strtolower($matches[1]);
            $imageData = substr($base64Image, strpos($base64Image, ',') + 1);
            $imageData = base64_decode($imageData);
        } else {
            throw new \Exception('Invalid base64 image format.');
        }

        $fileName = uniqid('job_', true) . '.' . $extension;
        $filePath = 'uploads/job_photos/' . $fileName;

        Storage::disk('public')->put($filePath, $imageData);

        $jobOffer->photos()->create([
            'file_path' => $filePath,
            'original_name' => $fileName,
            'file_size' => strlen($imageData),
        ]);
    }
}
