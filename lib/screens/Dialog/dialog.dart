import 'dart:ui';

import 'package:flutter/material.dart';

class ShareDialog extends StatefulWidget {

  const ShareDialog({Key? key,}) : super(key: key);

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {

  final List iconList=[
    'assets/dialog_icons/Group 427324337.png',
    'assets/dialog_icons/Vector.png',
    'assets/dialog_icons/Group.png',
    'assets/dialog_icons/Group 427324338.png'
  ];
  @override
  Widget build(BuildContext context) {
    return

      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Color(0xff2F2F2F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child:Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [

                  Icon(Icons.close,color: Color(0xf80FFFFFF),),

                ],),
                SizedBox(height: 10,),
                Center(
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle
                    ),
                    child: Icon(Icons.share,color: Colors.white,),
                  ),
                ),
                SizedBox(height: 20,),
                Center(
                  child: Text(
                    'Share Music',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Lexend Deca',
                      fontWeight: FontWeight.w500,
                      height: 0.07,
                    ),
                  ),
                ),
                SizedBox(height: 20,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:List.generate(iconList.length, (index) => Image(
                    height: 30,width: 30,
                    image: AssetImage(iconList[index].toString()),)),),
                SizedBox(height: 20,),
                Center(
                  child: Container(
                    width: MediaQuery.sizeOf(context).width*0.30,
                    height: 40,
                    decoration: ShapeDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0.00, -1.00),
                        end: Alignment(0, 1),
                        colors: [Color(0xFFB917DC), Color(0xFFDB05C6)],
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      shadows: [
                        BoxShadow(
                          color: Color(0x2B000000),
                          blurRadius: 4,
                          offset: Offset(0, 0),
                          spreadRadius: 0,
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'OK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Lexend Deca',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),



              ],
            ),
          ),
        ),
      );
  }
}