
import { supabase } from './src/db/supabase';

async function checkStorage() {
    console.log('Checking Supabase Storage buckets...');
    const { data, error } = await supabase.storage.listBuckets();

    if (error) {
        console.error('Error listing buckets:', error);
        return;
    }

    console.log('Buckets:', data);

    // Check if 'thumbnails' or 'recipe-thumbnails' exists
    const thumbnailBucket = data.find(b => b.name === 'thumbnails' || b.name === 'recipe-thumbnails');

    if (thumbnailBucket) {
        console.log(`Found bucket: ${thumbnailBucket.name}`);
    } else {
        console.log('No specific thumbnail bucket found. We may need to create one named "recipe-thumbnails".');
    }
}

checkStorage();
