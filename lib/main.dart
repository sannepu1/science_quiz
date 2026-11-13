import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Science Signal',
      debugShowCheckedModeBanner: false,
      home: const QuizScreen(),
    );
  }
}

class ScienceQuestion {
  final String text;
  final String correctAnswer;

  ScienceQuestion({required this.text, required this.correctAnswer});

  factory ScienceQuestion.fromJson(Map<String, dynamic> json) {
    if (json['question'] == null || json['correct_answer'] == null) {
      throw Exception('Question data is missing');
    }

    // decode the %20 stuff
    String q = Uri.decodeComponent(json['question']);
    String a = Uri.decodeComponent(json['correct_answer']);

    if (a != 'True' && a != 'False') {
      throw Exception('Answer is not True or False');
    }

    return ScienceQuestion(text: q, correctAnswer: a);
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<ScienceQuestion> questions = [];
  bool loading = true;
  String? error;

  int current = 0;
  String? picked;
  int score = 0;
  List<String> answers = [];
  bool done = false;

  bool submitting = false;
  String submitText = '';


  @override
  void initState() {
    super.initState();
    getQuestions();
  }

  Future<void> getQuestions() async {
    // reset everything for a new round
    setState(() {
      loading = true;
      error = null;
      questions = [];
      current = 0;
      picked = null;
      score = 0;
      answers = [];
      done = false;
      submitText = '';
    });

    try {
      var url = Uri.https('opentdb.com', '/api.php', {
        'amount': '5',
        'category': '17',
        'difficulty': 'medium',
        'type': 'boolean',
        'encode': 'url3986',
      });

      var response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }

      var data = jsonDecode(response.body);

      if (data['response_code'] != 0) {
        throw Exception('API error, response_code is ${data['response_code']}');
      }

      List results = data['results'];
      if (results.length != 5) {
        throw Exception('Did not get 5 questions');
      }

      List<ScienceQuestion> temp = [];
      int i = 0;
      while (i < results.length) {
        temp.add(ScienceQuestion.fromJson(results[i]));
        i++;
      }

      setState(() {
        questions = temp;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void answer(String choice) {
    // already answered so ignore it
    if (picked != null) {
      return;
    }

    setState(() {
      picked = choice;
      answers.add(choice);
      if (choice == questions[current].correctAnswer) {
        score = score + 1;
      }
    });
  }

  void next() {
    if (picked == null) {
      return;
    }

    setState(() {
      if (current == 4) {
        done = true;
      } else {
        current = current + 1;
      }
      picked = null;
    });
  }

  Future<void> submit() async {
    if (submitting == true) {
      return;
    }

    setState(() {
      submitting = true;
      submitText = '';
    });

    // fake delay, this does NOT send anything
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      submitting = false;
      submitText = 'SIMULATION: no request was sent to a server, nothing was saved';
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (loading) {
      body = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (error != null) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Something went wrong loading the questions', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text(error!),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: getQuestions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (done) {
      body = resultsPage();
    } else {
      body = questionPage();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Science Signal Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
    );
  }

  Widget questionPage() {
    ScienceQuestion q = questions[current];

    // colors for the buttons
    Color? trueColor;
    Color? falseColor;
    if (picked != null) {
      if (q.correctAnswer == 'True') {
        trueColor = Colors.green;
      }
      if (q.correctAnswer == 'False') {
        falseColor = Colors.green;
      }
      if (picked == 'True' && q.correctAnswer != 'True') {
        trueColor = Colors.red;
      }
      if (picked == 'False' && q.correctAnswer != 'False') {
        falseColor = Colors.red;
      }
    }

    String feedback = '';
    Color feedbackColor = Colors.black;
    if (picked != null) {
      if (picked == q.correctAnswer) {
        feedback = 'Correct! The answer is ${q.correctAnswer}';
        feedbackColor = Colors.green;
      } else {
        feedback = 'Wrong, you picked $picked but the answer is ${q.correctAnswer}';
        feedbackColor = Colors.red;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Question ${current + 1} of 5', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (current + 1) / 5),
        const SizedBox(height: 20),

        Text(q.text, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: trueColor),
          onPressed: () {
            answer('True');
          },
          child: const Text('True'),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: falseColor),
          onPressed: () {
            answer('False');
          },
          child: const Text('False'),
        ),
        const SizedBox(height: 20),
        Text(feedback, style: TextStyle(fontSize: 16, color: feedbackColor)),

        const Spacer(),
        Text('Score: $score'),
        const SizedBox(height: 8),
        // button is disabled until they answer
        ElevatedButton(
          onPressed: picked == null ? null : next,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget resultsPage() {
    List<Widget> review = [];
    for (int i = 0; i < 5; i++) {
      bool right = false;
      if (answers[i] == questions[i].correctAnswer) {
        right = true;
      }

      review.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. ${questions[i].text}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Your answer: ${answers[i]}'),
                Text('Correct answer: ${questions[i].correctAnswer}'),
                Text(right ? 'Correct' : 'Incorrect', style: TextStyle(color: right ? Colors.green : Colors.red)),
              ],
            ),
          ),
        ),
      );
    }

    Map payload = {
      'score': score,
      'total': 5,
      'category': 'Science & Nature',
    };


    return ListView(
      children: [
        Text('Your score: $score / 5', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...review,
        const SizedBox(height: 20),
        const Text('Payload:'),
        Text(jsonEncode(payload)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: submitting ? null : submit,
          child: Text(submitting ? 'Submitting (simulation)...' : 'Submit Score (Simulation)'),
        ),
        const SizedBox(height: 10),
        Text(submitText, style: const TextStyle(color: Colors.orange)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: submitting ? null : getQuestions,
          child: const Text('Play Again'),
        ),
      ],
    );
  }
}