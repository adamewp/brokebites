import 'package:flutter/material.dart';

class IngredientsPage extends StatefulWidget {
  final Function(List<Map<String, dynamic>>, int) onNext;

  IngredientsPage({required this.onNext});

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Ingredients'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _portionsController,
              decoration: InputDecoration(
                labelText: 'Number of Portions',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ingredientController,
                    decoration: InputDecoration(
                      labelText: 'Ingredient',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_ingredientController.text.isNotEmpty) {
                      _addIngredient(_ingredientController.text);
                      _ingredientController.clear();
                    }
                  },
                  child: Text('Add'),
                ),
              ],
            ),
            SizedBox(height: 16),
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
                          child: Text(_ingredients[index]['name']),
                        ),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Amount',
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _updateIngredient(
                                index,
                                value,
                                _ingredients[index]['unit'],
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _ingredients[index]['unit'],
                            isExpanded: true,
                            items: _units.map((String unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              _updateIngredient(
                                index,
                                _ingredients[index]['amount'],
                                newValue!,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                int portions = int.tryParse(_portionsController.text) ?? 1;
                widget.onNext(_ingredients, portions);
              },
              child: Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}