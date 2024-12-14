import 'package:flutter/cupertino.dart';

class IngredientsPage extends StatefulWidget {
  final Function(List<Map<String, dynamic>>, int) onNext;

  const IngredientsPage({super.key, required this.onNext});

  @override
  _IngredientsPageState createState() => _IngredientsPageState();
}

class _IngredientsPageState extends State<IngredientsPage> {
  final TextEditingController _portionsController = TextEditingController();
  final TextEditingController _ingredientController = TextEditingController();
  
  final List<String> _units = [
    'g', 'kg', 'ml', 'L', 'cup', 'tbsp', 'tsp', 'oz', 'lb'
  ];
  List<Map<String, dynamic>> _ingredients = [];

  void _addIngredient(String name) {
    setState(() {
      _ingredients.add({
        'name': name,
        'amount': '',
        'unit': 'g',
      });
    });
  }

  void _updateIngredient(int index, String amount, String unit) {
    setState(() {
      _ingredients[index]['amount'] = amount;
      _ingredients[index]['unit'] = unit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add Ingredients'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: const Color(0xFFFAF8F5),
        transitionBetweenRoutes: false,
      ),
      backgroundColor: const Color(0xFFFAF8F5),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _portionsController,
                placeholder: 'Number of Portions',
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _ingredientController,
                      placeholder: 'Ingredient',
                      decoration: BoxDecoration(
                        border: Border.all(color: CupertinoColors.systemGrey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    onPressed: () {
                      if (_ingredientController.text.isNotEmpty) {
                        _addIngredient(_ingredientController.text);
                        _ingredientController.clear();
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _ingredients.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              _ingredients[index]['name'],
                              style: const TextStyle(color: CupertinoColors.black),
                            ),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              placeholder: 'Amount',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) {
                                _updateIngredient(
                                  index,
                                  value,
                                  _ingredients[index]['unit'],
                                );
                              },
                              decoration: BoxDecoration(
                                border: Border.all(color: CupertinoColors.systemGrey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: CupertinoColors.systemGrey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  showCupertinoModalPopup(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return CupertinoActionSheet(
                                        actions: _units.map((unit) {
                                          return CupertinoActionSheetAction(
                                            onPressed: () {
                                              _updateIngredient(
                                                index,
                                                _ingredients[index]['amount'],
                                                unit,
                                              );
                                              Navigator.pop(context);
                                            },
                                            child: Text(unit),
                                          );
                                        }).toList(),
                                        cancelButton: CupertinoActionSheetAction(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: Text(
                                  _ingredients[index]['unit'],
                                  style: const TextStyle(color: CupertinoColors.black),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              CupertinoButton.filled(
                onPressed: () {
                  int portions = int.tryParse(_portionsController.text) ?? 1;
                  widget.onNext(_ingredients, portions);
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}