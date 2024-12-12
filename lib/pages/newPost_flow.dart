import 'package:flutter/material.dart';
import 'ingredientsInput_page.dart';
import 'postDetails_page.dart';

class NewPostFlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IngredientsPage(
      onNext: (ingredients, portions) {
        Navigator.push(
          context,
          MaterialPageRoute(
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