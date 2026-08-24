// import 'package:beatjerky/screens/order_screen/models/order_model.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';

// class OrderTile extends StatelessWidget {
//   final OrderModel order;
//   final bool isSellerView;
//   final VoidCallback? onMarkAsDispatched;
//   final VoidCallback? onMarkAsDelivered;

//   const OrderTile({
//     super.key,
//     required this.order,
//     required this.isSellerView,
//     this.onMarkAsDispatched,
//     this.onMarkAsDelivered,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 // placeholder for product image
//                 Container(
//                   width: 64,
//                   height: 64,
//                   color: Colors.grey.shade300,
//                   child: order.productImage.isNotEmpty
//                       ? CachedNetworkImage(imageUrl:  order.productImage, fit: BoxFit.cover, placeholder: (context, url) => Container(
//                                 color: Colors.grey[800],
//                                 child: const Center(
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(
//                                       Colors.white,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               errorWidget: (context, url, error) => const Icon(
//                                 Icons.inventory,
//                                 size: 48,
//                                 color: Colors.white24,
//                               ),)
//                       : const Icon(Icons.image),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         order.productName,
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'Qty: ${order.quantity} • Price: ${(order.price/100).toStringAsFixed(2)}',
//                       ),
//                     ],
//                   ),
//                 ),
//                 Chip(label: Text(order.status.toUpperCase())),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Buyer: ${order.buyerName}'),
//                 Text('Seller: ${order.sellerName}'),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 if (isSellerView && order.status == 'pending')
//                   ElevatedButton(
//                     onPressed: onMarkAsDispatched,
//                     child: const Text('Mark as Dispatched'),
//                   ),
//                 if (!isSellerView && order.status == 'dispatched')
//                   ElevatedButton(
//                     onPressed: onMarkAsDelivered,
//                     child: const Text('Mark as Delivered'),
//                   ),
//                 const SizedBox(width: 8),
//                 Text('Created: ${order.createdAt.toDate()}'),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:beatjerky/screens/order_screen/models/order_model.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class OrderTile extends StatelessWidget {
  final OrderModel order;
  final bool isSellerView;
  final VoidCallback? onMarkAsDispatched;
  final VoidCallback? onMarkAsDelivered;

  const OrderTile({
    super.key,
    required this.order,
    required this.isSellerView,
    this.onMarkAsDispatched,
    this.onMarkAsDelivered,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orangeAccent;
      case 'dispatched':
        return Colors.blueAccent;
      case 'delivered':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
     decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:recntsColor,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Product Section ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: order.productImage,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey[800],
                      child: const Icon(Icons.inventory_2,
                          size: 40, color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Qty: ${order.quantity}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: \$${(order.price / 100).toStringAsFixed(2)}',
                        style:  TextStyle(
                            color: recntsColor, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Status Chip
                Chip(
                  label: Text(
                    order.status.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor:
                      _getStatusColor(order.status).withValues(alpha: 0.8),
                  side: BorderSide(color: _getStatusColor(order.status)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),

            // ─── Buyer/Seller Info ────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Buyer: ${order.buyerName}',
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Seller: ${order.sellerName}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── Actions & Date ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Buttons
                Row(
                  children: [
                    if (isSellerView && order.status == 'pending')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onMarkAsDispatched,
                        child: const Text('Mark Dispatched',
                            style: TextStyle(color: Colors.white)),
                      ),
                    if (!isSellerView && order.status == 'dispatched')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade400,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onMarkAsDelivered,
                        child: const Text('Mark Delivered',
                            style: TextStyle(color: Colors.black)),
                      ),
                  ],
                ),

                // Created Date
                Text(
                  '📅 ${order.createdAt.toDate().toLocal().toString().split(' ').first}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white54, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
