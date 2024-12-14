import 'package:flutter/cupertino.dart';
import 'ingredientsInput_page.dart';
import 'postDetails_page.dart';

class NewPostFlow extends StatelessWidget {
  const NewPostFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return IngredientsPage(
      onNext: (ingredients, portions) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => PostDetailsPage(
              ingredients: ingredients,
              portions: portions,
            ),
          ),
        );
      },
    );
  }
}