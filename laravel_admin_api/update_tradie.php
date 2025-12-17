<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

$tradie = App\Models\Tradie::find(2);
if ($tradie) {
    $tradie->service_category_id = 13;
    $tradie->business_name = 'Networking Services';
    $tradie->save();
    echo "Updated tradie: {$tradie->first_name} {$tradie->last_name}\n";
    echo "Category ID: {$tradie->service_category_id}\n";
    echo "Business Name: {$tradie->business_name}\n";
} else {
    echo "Tradie not found\n";
}
