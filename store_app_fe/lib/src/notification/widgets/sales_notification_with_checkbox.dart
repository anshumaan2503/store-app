// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../../constants/enums.dart';


// // ignore: must_be_immutable
// class SalesNotificationWithCheckbox extends ConsumerStatefulWidget {
//    List<SalesNotification> userTypeList;
//   bool userTypeState;
//   final SalesNotification userType;

//    SalesNotificationWithCheckbox({
//     super.key,
//     required this.userTypeList,
//     this.userTypeState = false,
//     required this.userType,
//   });
//   // const SalesNotificationWithCheckbox({ super.key });

//   @override
//   ConsumerState<SalesNotificationWithCheckbox> createState() => _SalesNotificationWithCheckboxState();
// }

// class _SalesNotificationWithCheckboxState extends ConsumerState<SalesNotificationWithCheckbox> {
// @override
//  Widget build(BuildContext context) {
//     setState(() {
//       widget.userTypeState = widget.userTypeList.contains(widget.userType);
//     });
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Checkbox(
//           value: widget.userTypeState,
//           onChanged: (value) {
//             setState(() {
//               widget.userTypeState = value!;
//             });
//             if (widget.userTypeState) {
//               setState(() {
//                 widget.userTypeList.add(widget.userType);
//               });
//             } else {
//               setState(() {
//                 widget.userTypeList.remove(widget.userType);
//               });
//             }
//           },
//         ),
//         Text(widget.userType.label)
//       ],
//     );
//   }
// }