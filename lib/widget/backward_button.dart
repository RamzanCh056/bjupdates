import 'package:flutter/material.dart';

import '../utils/color.dart';


class BackwardButton extends StatelessWidget {
  // final VoidCallback onTap;
  const BackwardButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: (){
        Navigator.pop(context);
      },
      child: Container(
        height: 50,
        width: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: lightBlackColor,width: 2
          ),
        ),
        child: const Icon(
          Icons.arrow_back_ios,
          color: whiteColor,
        ),
      ),
    );
  }
}