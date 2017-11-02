Get assets (images and videos) from Android

# Install
```
npm i --save https://github.com/andrewgouin/react-native-cloudinary/tarball/master
```

Add to settings.gradle
```
include ':react-native-cloudinary'
project(':react-native-cloudinary').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-cloudinary/android')
```

Add to /app/build.gradle dependencies
```
  compile project(':react-native-cloudinary')
```

Add to MainApplication.java
```
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

# Usage
```
import Cloudinary from 'react-native-cloudinary';
...
//TODO usage
...
```
# react-native-cloudinary
