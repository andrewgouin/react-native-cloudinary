# Install
```bash
npm i --save https://github.com/andrewgouin/react-native-cloudinary/tarball/master
```
## Android

Add to settings.gradle
```javascript
include ':react-native-cloudinary'
project(':react-native-cloudinary').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-cloudinary/android')
```

Add to /app/build.gradle dependencies
```javascript
  compile project(':react-native-cloudinary')
```

Add to MainApplication.java
```java
import com.agouin.cloudinary.RNCloudinaryPackage;
...
  public List<ReactPackage> getPackages() {
    return Arrays.<ReactPackage>asList(
    new RNCloudinaryPackage(),
    ...
     );
  }
...
```

## iOS

Add to podfile
```javascript
  pod 'AFNetworking', '~> 3.0'
  pod 'react-native-cloudinary', path: '../node-modules/react-native-cloudinary'
```

```bash
cd ios/
pod install
```

# Usage
```javascript
import Cloudinary from 'react-native-cloudinary';

let progressListener = ({progress, id}) => {
  console.log('received progress event', progress);
};
// Get progress events
Cloudinary.addUploadProgressListener(progressListener); //before upload

Cloudinary.upload(url, // url after https://api.cloudinary.com/
                  uri, // uri to media
                  filename, // file name
                  signature, // signature to sign parameters
                  apiKey, // api key for signing
                  timestamp, // timestamp in epoch time
                  colors, // boolean matching what was requested from cloudinary
                  returnDeleteToken, // boolean matching what was requested from cloudinary
                  format, // string matching what was requested from cloudinary (null if not used)
                  type, // mimetype
                  id // upload id, unique id that will be sent back in progress event
          .then(r => /* Cloudinary response in r including public_id, etc. */)
          .catch(e => /* Cloudinary error in e*/);

Cloudinary.removeUploadProgressListener(progressListener); //after upload
```

