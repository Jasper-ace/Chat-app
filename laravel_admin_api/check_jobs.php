<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

$jobs = App\Models\HomeownerJobOffer::all(['id', 'title', 'service_category_id', 'status']);

echo "Total jobs: " . $jobs->count() . "\n\n";

foreach ($jobs as $job) {
    echo "ID: {$job->id}\n";
    echo "Title: {$job->title}\n";
    echo "Category ID: {$job->service_category_id}\n";
    echo "Status: {$job->status}\n";
    echo "---\n";
}
