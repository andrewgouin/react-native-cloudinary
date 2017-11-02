package com.agouin.cloudinary;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.GuardedAsyncTask;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;


import android.database.Cursor;
import android.net.Uri;
import android.os.AsyncTask;

import android.provider.OpenableColumns;
import android.support.annotation.Nullable;
import android.util.Log;


import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.TimeUnit;

import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.OkHttpClient;
import okhttp3.RequestBody;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;
import retrofit2.converter.scalars.ScalarsConverterFactory;
import retrofit2.http.Header;
import retrofit2.http.Multipart;
import retrofit2.http.POST;
import retrofit2.http.Part;
import retrofit2.http.PartMap;
import retrofit2.http.Url;

class Cloudinary extends ReactContextBaseJavaModule {

  private static final String TAG = "RNCloudinary";


  public Cloudinary(ReactApplicationContext reactContext) {
    super(reactContext);
  }

  @Override
  public String getName() {
    return "Cloudinary";
  }

  @ReactMethod
  public void upload(String url, String uri, String filename, String signature, String apiKey, String timestamp, String colors, String returnDeleteToken, @Nullable String format, String type, Promise promise) {
    new UploadTask(getReactApplicationContext(), url, uri, filename, signature, apiKey, timestamp, colors, returnDeleteToken, format, type, promise).executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
  }

  protected static String getSaltString() {
    String SALTCHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
    StringBuilder salt = new StringBuilder();
    Random rnd = new Random();
    while (salt.length() < 18) { // length of the random string.
      int index = (int) (rnd.nextFloat() * SALTCHARS.length());
      salt.append(SALTCHARS.charAt(index));
    }
    String saltStr = salt.toString();
    return saltStr;
  }

  private static class UploadTask extends GuardedAsyncTask<Void,Void> {
    private final ReactApplicationContext mContext;
    private final Promise mPromise;
    private final String mUrl;
    private final Uri mUri;
    private final String mUniqueId, mFilename;
    private Retrofit mRetrofit;
    private CloudinaryService mService;
    private InputStream mFileStream;
    private final int mSize;
    private final String mType;
    private boolean mShouldStop = false;
    private static final int CHUNK_SIZE = 6000000;
    private static final Map<String, RequestBody> params = new HashMap<>();

    private interface CloudinaryService {
      @Multipart
      @POST
      Call<JsonObject> uploadChunkCall(@Url String url, @Header("X-Unique-Upload-Id") String uniqueId, @Header("Content-Range") String contentRange, @Part MultipartBody.Part chunk, @PartMap Map<String,RequestBody> params);
    }

    private RequestBody toRequestBody(String string) {
      return RequestBody.create(MultipartBody.FORM, string);
    }

    protected UploadTask(
            ReactApplicationContext context,
            String url,
            String uri,
            String filename,
            String signature,
            String apiKey,
            String timestamp,
            String colors,
            String returnDeleteToken,
            String format,
            String type,
            Promise promise) {
      super(context);
      Gson gson = new GsonBuilder()
              .disableHtmlEscaping()
              .create();
      this.mPromise = promise;
      this.mUniqueId = getSaltString();
      this.mContext = context;
      this.mUrl = url;
      this.mType = type;
      this.mFilename = filename;
      params.put("signature", toRequestBody(signature));
      params.put("timestamp",toRequestBody(timestamp));
      params.put("api_key", toRequestBody(apiKey));
      params.put("return_delete_token", toRequestBody(returnDeleteToken));
      params.put("colors", toRequestBody(colors));
      if (format != null) {
        params.put("format", toRequestBody(format));
      }
      final OkHttpClient okHttpClient = new OkHttpClient.Builder()
              .readTimeout(60, TimeUnit.SECONDS)
              .connectTimeout(60, TimeUnit.SECONDS)
              .writeTimeout(60, TimeUnit.SECONDS)
              .build();
      this.mRetrofit = new Retrofit.Builder()
              .addConverterFactory(ScalarsConverterFactory.create())
              .addConverterFactory(GsonConverterFactory.create(gson))
              .client(okHttpClient)
              .baseUrl("https://api.cloudinary.com/").build();
      this.mUri = Uri.parse(uri);
      this.mService = mRetrofit.create(CloudinaryService.class);
      final long fileSize;
      Cursor returnCursor = context.getContentResolver().query(mUri, null, null, null, null, null);
      if (returnCursor != null) {
        int sizeIndex = returnCursor.getColumnIndex(OpenableColumns.SIZE);
        returnCursor.moveToFirst();
        fileSize = returnCursor.getLong(sizeIndex);
      } else {
        File file = new File(mUri.getPath());
        if (file != null) {
          fileSize = file.length();
        } else {
          mPromise.reject("Unable to access file", "Can't determine file size");
          mShouldStop = true;
          this.mSize = 0;
          return;
        }
      }

      if (fileSize > 300000000) {
        promise.reject("File too big","The file maximum size is 300MB");
        this.mShouldStop = true;
        this.mSize = 0;
        return;
      } else {
        this.mSize = Math.toIntExact(fileSize);
      }
      try {
        this.mFileStream = context.getContentResolver().openInputStream(Uri.parse(uri));
      } catch (FileNotFoundException e) {
        this.mShouldStop = true;
        promise.reject("File not found","The requested media could not be found");
        return;
      }


    }

    private void uploadChunk(int firstByte) {
      final int lastByte;
      int chunkSize = CHUNK_SIZE;
      final boolean shouldContinue;
      if ((firstByte + CHUNK_SIZE)> mSize) {
        lastByte = mSize - 1;
        chunkSize = Math.toIntExact(mSize - firstByte);
        shouldContinue = false;
      } else {
        lastByte = firstByte + CHUNK_SIZE - 1;
        shouldContinue = true;
      }
      final byte[] chunk = new byte[chunkSize];
      try {
        mFileStream.read(chunk, 0, chunkSize);
      } catch (IOException e) {
        this.mShouldStop = true;
        mPromise.reject("File read error", "There was a problem reading from the file");
        return;
      }

      RequestBody typedBytes = RequestBody.create(MediaType.parse(mType), chunk);
      MultipartBody.Part filePart = MultipartBody.Part.createFormData("file", mFilename, typedBytes);
      try {
        Log.d("SIZE", "first byte: " + firstByte + " lastByte: " + lastByte + " size:" + mSize + " chunk size: " + Long.toString(typedBytes.contentLength()));
      } catch (IOException e) {
        e.printStackTrace();
      }
      Call<JsonObject> response = mService.uploadChunkCall(mUrl, mUniqueId, "bytes " + firstByte + "-" + lastByte + "/" + mSize, filePart, params);
      response.enqueue(new Callback<JsonObject>() {
        @Override
        public void onResponse(Call<JsonObject> call, Response<JsonObject> response) {
          if (response.errorBody() != null) {
            String errorMessage;
            try {
              errorMessage = response.errorBody().string();
            } catch( Exception e) {
              errorMessage = "Fatal error";
            }
            mPromise.reject("Cloudinary upload error", errorMessage);
          } else {
            WritableMap specificParams = Arguments.createMap();
            specificParams.putDouble("progress", lastByte / mSize);
            if (mContext.hasActiveCatalystInstance()) {
              mContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                      .emit("uploadProgress", specificParams);
            }
            if (shouldContinue && !mShouldStop) {
              uploadChunk(lastByte + 1);
            } else {
              mPromise.resolve(response.body().toString());
            }
          }
        }

        @Override
        public void onFailure(Call<JsonObject> call, Throwable t) {
          mShouldStop = true;
          mPromise.reject("Upload failure", "Cloudinary request failure");
        }
      });

    }

    @Override
    protected void doInBackgroundGuarded(Void... params) {
      //upload to cloudinary and emit progress events
      uploadChunk(0);
    }
  }
}

