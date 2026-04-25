import 'package:flutter/material.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.person_add_alt_1_rounded))
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF161F2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) {
                final names = ['Alex Johnson', 'Sarah Miller', 'Mike Ross'];
                final steps = ['8,420', '12,100', '4,500'];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey[800],
                    child: Text(names[index][0]),
                  ),
                  title: Text(names[index]),
                  subtitle: Text('Today: ${steps[index]} steps'),
                  trailing: const Icon(Icons.bar_chart_rounded, color: const Color(0xFF3ABEF9)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
