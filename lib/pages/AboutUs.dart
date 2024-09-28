import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';

class AboutUsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(text: "About Us"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(
                text: "About Us",
                size: 24,
                weight: FontWeight.bold,
              ),
              SizedBox(height: 20),
              Align(
                alignment: Alignment.center,
                child: CustomText(
                  text: "We’re a group of students from STI College Batangas "
                      "who came together to make life a little easier for our fellow students. "
                      "Our app, UniStock, helps streamline the process of buying uniforms "
                      "and staying updated with school announcements.",
                ),
              ),
              SizedBox(height: 20),
              CustomText(
                text: "Meet the Team:",
                size: 20,
                weight: FontWeight.bold,
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.center,
                child: CustomText(
                  text: "Charles Kenneth Adelantar\n"
                      "James Lawrence Peralta\n"
                      "Desiree Magadia\n"
                      "Mac Ivan Llagas",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}