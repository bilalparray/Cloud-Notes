# Firebase Storage CORS (for image preview on web)

Image previews in notes load on web using the browser's native `<img>` element, so they work **without** CORS in most cases.

If you still see broken images on web (e.g. after changing how images are loaded), you can allow Flutter to load images directly by configuring CORS on your Storage bucket:

1. **Bucket name**  
   In [Firebase Console](https://console.firebase.google.com) → your project → **Storage**, note the bucket (e.g. `cloud-notes-8e62d.appspot.com` or `cloud-notes-8e62d.firebasestorage.app`).

2. **Apply CORS** (Google Cloud SDK required):
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   gsutil cors set storage_cors.json gs://YOUR_BUCKET_NAME
   ```
   Replace `YOUR_PROJECT_ID` and `YOUR_BUCKET_NAME` with your project id and the bucket name from step 1.

3. **`storage_cors.json`** in this project allows `GET` from any origin so image requests from your web app are allowed.
