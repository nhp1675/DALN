import 'package:intl/intl.dart';
import 'api.dart';

String money(dynamic n) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
).format(n is num ? n : 0);
DateTime vnDate(dynamic s) =>
    DateTime.parse(sid(s)).toUtc().add(const Duration(hours: 7));
String dateTime(dynamic s) {
  try {
    return DateFormat('HH:mm dd/MM/yyyy').format(vnDate(s));
  } catch (_) {
    return '—';
  }
}

String time(dynamic s) {
  try {
    return DateFormat('HH:mm').format(vnDate(s));
  } catch (_) {
    return '—';
  }
}

String shortDate(dynamic s) {
  try {
    return DateFormat('dd/MM').format(vnDate(s));
  } catch (_) {
    return '—';
  }
}

Json? byId(List<Json> items, dynamic id) {
  for (final x in items) {
    if (sid(x['_id']) == sid(id)) return x;
  }
  return null;
}

const states = {
  'pending': 'Chờ thanh toán',
  'paid': 'Đã thanh toán',
  'expired': 'Hết hạn',
  'cancelled': 'Đã hủy',
  'valid': 'Còn hiệu lực',
  'used': 'Đã sử dụng',
  'available': 'Trống',
  'held': 'Đang giữ',
  'booked': 'Đã đặt',
  'success': 'Thành công',
  'failed': 'Thất bại',
  'now': 'Đang chiếu',
  'soon': 'Sắp chiếu',
  'archived': 'Đã ẩn',
  'active': 'Hoạt động',
  'booking': 'Đặt vé',
  'exchange': 'Đổi vé',
  'customer': 'Khách hàng',
  'admin': 'Quản trị',
};
String status(dynamic v) => states[sid(v)] ?? sid(v);
