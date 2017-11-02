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
...
Cloudinary.upload(url,
                  uri,
                  filename,
                  signature,
                  apiKey,
                  timestamp,
                  colors,
                  returnDeleteToken,
                  format,
                  type)
          .then(r => /* Cloudinary response in r*/)
          .catch(e => /* Cloudinary error in e*/);
...
```

