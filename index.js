import { NativeModules, DeviceEventEmitter } from 'react-native';

var listeners = {};
var uploadProgressEvent = 'uploadProgress';

var id = 0;
var META = '__listener_id0';

function getKey(listener) {
  if (!listener.hasOwnProperty(META)) {
    if (!Object.isExtensible(listener)) {
      return 'F';
    }

    Object.defineProperty(listener, META, {
      value: 'L' + ++id,
    });
  }
  return listener[META];
}
module.exports = {
  ...NativeModules.Cloudinary,
  addUploadProgressListener(cb) {
    var key = getKey(cb);

    listeners[key] = DeviceEventEmitter.addListener(
      uploadProgressEvent,
      body => {
        cb(body.progress);
      },
    );
  },

  removeUploadProgressListener(cb) {
    var key = getKey(cb);

    if (!listeners[key]) {
      return;
    }

    listeners[key].remove();
    listeners[key] = null;
  },
};
