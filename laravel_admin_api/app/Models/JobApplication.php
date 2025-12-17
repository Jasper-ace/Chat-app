<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JobApplication extends Model
{
    protected $fillable = [
        'job_offer_id',
        'tradie_id',
        'status',
        'cover_letter',
        'proposed_price',
    ];

    protected $casts = [
        'proposed_price' => 'decimal:2',
    ];

    public function jobOffer(): BelongsTo
    {
        return $this->belongsTo(HomeownerJobOffer::class, 'job_offer_id');
    }

    public function tradie(): BelongsTo
    {
        return $this->belongsTo(Tradie::class);
    }
}
