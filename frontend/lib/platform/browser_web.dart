import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<(double, double)> locate() {
  final completer = Completer<(double, double)>();
  web.window.navigator.geolocation.getCurrentPosition(
    ((web.GeolocationPosition p) {
      if (!completer.isCompleted) {
        completer.complete((p.coords.latitude, p.coords.longitude));
      }
    }).toJS,
    ((web.GeolocationPositionError e) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(
            e.code == 1
                ? 'Bạn chưa cấp quyền vị trí. Hãy chọn thành phố.'
                : 'Không xác định được vị trí. Hãy thử lại.',
          ),
        );
      }
    }).toJS,
    web.PositionOptions(
      enableHighAccuracy: false,
      timeout: 10000,
      maximumAge: 60000,
    ),
  );
  return completer.future.timeout(const Duration(seconds: 15));
}

void openExternal(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}

void downloadData(String name, String dataUrl) {
  final anchor = web.HTMLAnchorElement()
    ..href = dataUrl
    ..download = name;
  anchor.click();
}
