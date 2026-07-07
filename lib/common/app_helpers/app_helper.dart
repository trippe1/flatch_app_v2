// ignore_for_file: public_member_api_docs, sort_constructors_first, deprecated_member_use
import 'dart:convert';
import 'dart:math';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AppHelper {
static  String timeAgo(int timestampMillis) {
    final now = DateTime.now();
    final commentTime = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    final difference = now.difference(commentTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }

  static List<Map<String, String>> setAGoalHeadings = [
    {"SET CATEGORY".toUpperCase(): "Choose your goal category"},
    {"SET TIMELINE".toUpperCase(): "Define the time for success"},
    {"DESCRIBE GOAL".toUpperCase(): "Clarify your goal clearly"},
    {"GENERATE ROADMAP".toUpperCase(): "Plan the steps to success"},
  ];
  static List<String> domains = [
    "🎓 Student Visa",
    "💼 Work Visa",
    "Work Visa",
    "🧳 Visit Visa",
    "🏢 Business Visa",
  ];
  static List<String> steps = ['Category', 'Timeline', 'Describe', 'Roadmap'];

  static List<String> durations = [
    "3 Months",
    "1 Month",
    "1 Week",
    "Custom Duration",
  ];

  static List<String> habitDurations = [
    "21 days",
    "30 days",
    "66 days",
    "Custom Duration",
  ];

  static List<String> jokes = [
    "🚜: Why did the scarecrow become a successful neurosurgeon? Because he was outstanding in his field! 🤓🧠",
    "🐶: What do you call a dog magician? A labracadabrador! 🪄✨",
    "🏖️: Why don’t seagulls fly over the bay? Because then they'd be bagels! 🥯😂",
    "🚀: Why don’t scientists trust atoms? Because they make up everything! 🤣🧪",
    "🎸: Why couldn’t the bicycle stand up by itself? It was two-tired! 🚴‍♂️😆",
    "🍕: Want to hear a joke about pizza? Never mind, it’s too cheesy! 🧀😄",
    "👻: Why did the ghost go to the party? Because he heard it was going to be a boo-l! 👻🎉",
    "🐸: Why are frogs so happy? Because they eat whatever bugs them! 🐛😋",
    "🍔: What do you call fake spaghetti? An impasta! 🍝😂",
    "🐦: What do you call a canary in a food mixer? Shredded tweet! 😂🕊️",
    "🧛‍♂️: Why don’t vampires ever get sick?\nBecause they’re always coffin! 😷😂",
    "🐧: Why don’t penguins like talking to strangers at parties?\nBecause they find it hard to break the ice! 🧊🐧",
    "🍌: Why did the banana go to the doctor?\nBecause it wasn’t peeling well! 🤒🍌",
    "🌮: What do you call a tortilla chip that plays music?\nA rap-salsa! 🎤🌮",
    "🦖: What do you call a dinosaur with an extensive vocabulary?\nA thesaurus! 📚🦖",
    "🎩: Why was the math book sad?\nBecause it had too many problems! 📖😢",
    "🍫: Why did the cookie go to the hospital?\nBecause it felt crumby! 🍪😷",
    "🌟: How do you organize a space party?\nYou planet! 🪐🎉",
    "🐓: Why did the chicken join a band?\nBecause it had the drumsticks! 🥁🐔",
    "🧀: What do you call cheese that isn’t yours?\nNacho cheese! 😆🧀",
  ];

  static List<String> daysNames = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];
  static List<String> daysNamesWithEmojis = [
    "Sunday 🌞",
    "Monday 🌕",
    "Tuesday 🔥",
    "Wednesday 🍃",
    "Thursday ⚡",
    "Friday 💧",
    "Saturday 🌈",
  ];
  static List<String> dailyTime = [
    "15 min",
    "30 min",
    "1 hr",
    "2 hrs",
    "3 hrs",
    "4 hrs",
    "6 hrs",
    "8 hrs",
    "10 hrs",
  ];

  static List<List<DateTime>> getWeeklyDatesBetween(
    DateTime startDate,
    DateTime endDate,
  ) {
    List<List<DateTime>> weeklyDates = [];
    List<DateTime> currentWeek = [];
    DateTime currentDate = startDate;

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      currentWeek.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));

      if (currentWeek.length == 7 ||
          (currentDate.isAfter(endDate) && currentWeek.isNotEmpty)) {
        weeklyDates.add(List<DateTime>.from(currentWeek));
        currentWeek.clear();
      }
    }

    return weeklyDates;
  }

  static Future<Duration?> pickDuration(BuildContext context) async {
    Duration duration = Duration.zero;
    double height = context.screenHeight;
    double width = context.screenWidth;

    double sheetHeight = height < 600 ? height * 0.7 : 390;

    Duration? result = await showModalBottomSheet<Duration>(
      context: context,
      constraints: BoxConstraints(maxHeight: sheetHeight),
      backgroundColor: Colors.white,
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            width: width,
            padding: const EdgeInsets.all(15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextWidget(
                  text: "Pick Time",
                  size: 22,
                  weight: FontWeight.w700,
                ),
                const Gap(5),
                TextWidget(
                  text: "Select the time you want to complete this to-do",
                  color: Colors.black.withOpacity(.6),
                  textAlign: TextAlign.center,
                ),
                const Gap(20),
                SizedBox(
                  height: 150, // Set a fixed height for the timer picker
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hms,
                    onTimerDurationChanged: (onChange) {
                      duration = onChange;
                    },
                    initialTimerDuration: const Duration(minutes: 0),
                  ),
                ),
                const Gap(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    2,
                    (index) => TextButton(
                      onPressed: () {
                        if (index == 0) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pop(context, duration);
                        }
                      },
                      style: ButtonStyle(
                        minimumSize: MaterialStateProperty.all(
                          const Size(140, 40),
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor: MaterialStateProperty.all(
                          index == 0 ? AppColors.background : null,
                        ),
                        foregroundColor: MaterialStateProperty.all(
                          index == 0 ? AppColors.primary : null,
                        ),
                      ),
                      child: Text(index == 0 ? "Cancel" : "Start Time"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }

  //! Suggested Habits
  static List<Map<String, dynamic>> suggestedHabits = [
    {
      "category": "👨‍👩‍👧‍👦 Family & Relationships",
      "habits": [
        {
          "heading": "Make this Habit",
          "habit": "Check in with a friend",
          "stop": "Neglecting relationships",
          "start": "Call or text a friend weekly",
          "continueHabit": "Stronger friendships and better social support",
        },
        {
          "heading": "Make this Habit",
          "habit": "Eat dinner with family",
          "stop": "Skipping family meals",
          "start": "Have at least one meal together daily",
          "continueHabit": "Better family bonding and communication",
        },
        {
          "heading": "Break this Habit",
          "habit": "Arriving late to functions",
          "stop": "Procrastinating before leaving",
          "start": "Plan ahead and set reminders",
          "continueHabit": "Improved punctuality and respect for others' time",
        },
        {
          "heading": "Break this Habit",
          "habit": "Neglecting family and friends' need for attention",
          "stop": "Ignoring messages and invitations",
          "start": "Schedule time to connect with loved ones",
          "continueHabit": "Healthier, more fulfilling relationships",
        },
      ],
    },
    {
      "category": "💼 Career & Finances",
      "habits": [
        {
          "heading": "Make this Habit",
          "habit": "Weekly spending review",
          "stop": "Unconscious spending",
          "start": "Review and budget weekly expenses",
          "continueHabit": "Better financial control and savings",
        },
        {
          "heading": "Make this Habit",
          "habit": "Maintain work-life balance",
          "stop": "Overworking without breaks",
          "start": "Set work limits and take time off",
          "continueHabit": "Reduced stress and better mental health",
        },
        {
          "heading": "Break this Habit",
          "habit": "Saying yes to everything asked of you",
          "stop": "Overcommitting without boundaries",
          "start": "Learn to say no and set limits",
          "continueHabit": "More time and energy for important priorities",
        },
        {
          "heading": "Break this Habit",
          "habit": "Impulse buying",
          "stop": "Buying without thinking",
          "start": "Follow a 24-hour rule before purchases",
          "continueHabit": "More savings and financial discipline",
        },
      ],
    },
    {
      "category": "🏋️‍♀️ Fitness & Nutrition",
      "habits": [
        {
          "heading": "Make this Habit",
          "habit": "Incorporate more movement into your daily routine",
          "stop": "Sitting for long hours",
          "start": "Take short active breaks throughout the day",
          "continueHabit": "Improved physical health and energy levels",
        },
        {
          "heading": "Make this Habit",
          "habit": "Limit processed foods",
          "stop": "Eating too much junk food",
          "start": "Choose fresh, whole foods",
          "continueHabit": "Better digestion and long-term health",
        },
        {
          "heading": "Break this Habit",
          "habit": "Skipping exercise days",
          "stop": "Skipping workouts due to laziness",
          "start": "Schedule workout sessions and stick to them",
          "continueHabit": "Increased strength and endurance",
        },
        {
          "heading": "Break this Habit",
          "habit": "Going to bed late",
          "stop": "Using screens late at night",
          "start": "Set a bedtime routine and follow it",
          "continueHabit": "Better sleep quality and energy levels",
        },
      ],
    },
    {
      "category": "🧠 Mental Wellness",
      "habits": [
        {
          "heading": "Make this Habit",
          "habit": "Have a consistent bedtime routine",
          "stop": "Staying up late with no schedule",
          "start": "Create a relaxing pre-sleep ritual",
          "continueHabit": "Improved sleep and mental clarity",
        },
        {
          "heading": "Make this Habit",
          "habit": "Daily journaling",
          "stop": "Bottling up emotions",
          "start": "Write down thoughts and reflections daily",
          "continueHabit": "Greater self-awareness and reduced stress",
        },
        {
          "heading": "Break this Habit",
          "habit": "Limit screen time",
          "stop": "Excessive phone or TV usage",
          "start": "Set daily screen time limits",
          "continueHabit": "More time for meaningful activities",
        },
        {
          "heading": "Break this Habit",
          "habit": "Pent-up anger",
          "stop": "Suppressing emotions",
          "start": "Practice mindfulness and deep breathing",
          "continueHabit": "Better emotional balance and peace",
        },
      ],
    },
    {
      "category": "🎉 Fun & Leisure",
      "habits": [
        {
          "heading": "Make this Habit",
          "habit": "Engage in hobbies",
          "stop": "Prioritizing work over personal joy",
          "start": "Dedicate time to hobbies weekly",
          "continueHabit": "More fulfillment and stress relief",
        },
        {
          "heading": "Make this Habit",
          "habit": "Smile and laugh every day",
          "stop": "Dwelling on negativity",
          "start": "Seek humor and joy daily",
          "continueHabit": "Boosted mood and mental well-being",
        },
        {
          "heading": "Break this Habit",
          "habit": "Not making time for vacations",
          "stop": "Overworking without breaks",
          "start": "Plan and schedule vacations",
          "continueHabit": "More relaxation and work-life balance",
        },
        {
          "heading": "Break this Habit",
          "habit": "Fear of trying new things",
          "stop": "Avoiding new experiences",
          "start": "Step outside comfort zones regularly",
          "continueHabit": "More growth and life experiences",
        },
      ],
    },
  ];

  static List<DateTime> getWeekFromSundayToSaturday(DateTime selectedDateTime) {
    int daysToSunday = selectedDateTime.weekday % 7;
    DateTime startOfWeek = selectedDateTime.subtract(
      Duration(days: daysToSunday),
    );
    List<DateTime> weekDates = [];

    for (int i = 0; i <= 6; i++) {
      weekDates.add(startOfWeek.add(Duration(days: i)));
    }

    return weekDates;
  }

  //! Getting timerange for analytics section

  static String generateRandomCode() {
    Random random = Random();
    int generateRandomNumber(int digitCount) {
      int min = pow(10, digitCount - 1).toInt();
      int max = pow(10, digitCount).toInt() - 1;
      return min + random.nextInt(max - min + 1);
    }

    // Generate the parts of the code
    String part1 = generateRandomNumber(4).toString();
    String part2 = generateRandomNumber(4).toString();
    String part3 = generateRandomNumber(3).toString();

    // Combine the parts with dashes
    return '$part1-$part2-$part3';
  }

  List<String> extractListFromString(String input) {
    try {
      List data = jsonDecode(input);
      return data.map((e) {
        return e
            .toString()
            .replaceAll("Insight 1:", "")
            .replaceAll("Insight 2:", "")
            .replaceAll("Insight 3:", "")
            .replaceAll("[", "")
            .replaceAll("]", "")
            .replaceAll("(mood: h)", "")
            .replaceAll("(rememberThisDayBy: h)", "")
            .replaceAll("(1)", "")
            .replaceAll("(2)", "")
            .replaceAll("(3)", "")
            .replaceAll("(mood :1)", "");
      }).toList();
    } catch (e) {
      if (input.toLowerCase().contains("insight 1")) {
        List<String> content = [];
        List<String> result = extractInsights(
          input
              .replaceAll("[", "")
              .replaceAll("]", "")
              .replaceAll("(mood: h)", "")
              .replaceAll("(rememberThisDayBy: h)", "")
              .replaceAll("(1)", "")
              .replaceAll("(2)", "")
              .replaceAll("(3)", "")
              .replaceAll("(mood :1)", ""),
        );
        for (String s in result) {
          if (removeSpecialCharacters(s).trim().isNotEmpty) {
            content.add(s);
          }
        }
        return content;
      } else {
        RegExp regex = RegExp(r'\[(.*?)\]|"(.*?)"', dotAll: true);
        var matches = regex.allMatches(input);
        List<String> result = [];
        for (var match in matches) {
          String? content = match.group(1) ?? match.group(2);
          if (content != null) {
            List<String> extractedList =
                content.split(',').map((e) => e.trim()).toList();
            result.addAll(extractedList);
          }
        }
        return result;
      }
    }
  }

  List<String> extractInsights(String input) {
    RegExp regex = RegExp(r'Insight \d+:');

    input = 'Insight 0:$input';

    List<String> insights = input.split(regex).map((e) => e.trim()).toList();

    insights.removeAt(0);

    return insights;
  }

  String removeSpecialCharacters(String input) {
    RegExp regex = RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$');
    String cleanedString = input.replaceAll(regex, '');
    return cleanedString;
  }

  static final List<String> professions = [
    "Computer Software Engineer",
    "Doctor",
    "Teacher",
    "Freelancer",
    "Accountant",
    "Architect",
    "Artist",
    "Auto Mechanic",
    "Banker",
    "Barber",
    "Business Owner",
    "Cashier",
    "Chef",
    "Cleaner",
    "Construction Worker",
    "Consultant",
    "Content Writer",
    "Customer Service Representative",
    "Data Analyst",
    "Delivery Driver",
    "Dentist",
    "Driver",
    "Electrician",
    "Engineer",
    "Event Planner",
    "Farmer",
    "Fashion Designer",
    "Firefighter",
    "Fitness Trainer",
    "Graphic Designer",
    "Housekeeper",
    "Human Resource Manager",
    "Journalist",
    "Lab Technician",
    "Lawyer",
    "Lecturer",
    "Librarian",
    "Logistics Manager",
    "Machine Operator",
    "Marketing Executive",
    "Mason",
    "Mechanic",
    "Medical Assistant",
    "Nurse",
    "Office Assistant",
    "Painter",
    "Pharmacist",
    "Photographer",
    "Plumber",
    "Police Officer",
    "Receptionist",
    "Salesperson",
    "Scientist",
    "Security Guard",
    "Shopkeeper",
    "Social Media Manager",
    "Software Developer",
    "Student",
    "Tailor",
    "Taxi Driver",
    "Technician",
    "Telemarketer",
    "Trader",
    "Truck Driver",
    "Veterinarian",
    "Video Editor",
    "Waiter",
    "Web Developer",
    "Welder",
    "Writer",
  ];
  static final List<String> countries = [
    "Pakistan",
    "India",
    "Nigeria",
    "Bangladesh",
    "China",
    "Vietnam",
    "Indonesia",
    "Philippines",
  ];
  static final List<String> ages = [
    '18',
    '19',
    '20',
    '21',
    '22',
    '23',
    '24',
    '25',
    '26',
    '27',
    '28',
    '29',
    '30',
    '31',
    '32',
    '33',
    '34',
    '35',
    '36',
    '37',
    '38',
    '39',
    '40',
    '41',
    '42',
    '43',
    '44',
    '45',
    '46',
    '47',
    '48',
    '49',
    '50',
    '51',
    '52',
    '53',
    '54',
    '55',
    '56',
    '57',
    '58',
    '59',
    '60',
  ];

  static final Map<String, int> visaTypesWithCount = {
    'Business Visa': 0,
    'Student Visa': 12,
    'Work Visa': 8,
    'Visit Visa': 0,
  };

  static final List<String> destination = [
    'USA',
    'UK',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Japan',
    'China',
    'India',
    'Brazil',
    'Mexico',
    'Russia',
    'South Africa',
    'Egypt',
    'Nigeria',
    'Kenya',
    'Ghana',
    'South Korea',
    'Spain',
    'Italy',
  ];

  static final Map<String, Map<String, List<String>>> visaDestinations = {
    "Student Visa": {
      "top": [
        "United States",
        "United Kingdom",
        "Canada",
        "Australia",
        "Germany",
      ],
      "all": [
        "Belgium",
        "Brazil",
        "Finland",
        "France",
        "Italy",
        "Japan",
        "New Zealand",
        "Norway",
        "Singapore",
        "South Africa",
        "Turkey",
      ]..sort(),
    },
    "Work Visa": {
      "top": [
        "United Arab Emirates",
        "Saudi Arabia",
        "United States",
        "United Kingdom",
      ],
      "all": [
        "Australia",
        "Canada",
        "Japan",
        "Qatar",
        "Romania",
        "Singapore",
        "South Korea",
        "Turkey",
      ]..sort(),
    },
  };

  final List<Map<String, dynamic>> countriesData = [
    {
      "name": "United States",
      "code": "us",
      "phoneCode": "+1",
      "flag": "🇺🇸",
      "cities": ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix"],
    },
    {
      "name": "United Kingdom",
      "code": "gb",
      "phoneCode": "+44",
      "flag": "🇬🇧",
      "cities": [
        "London",
        "Manchester",
        "Birmingham",
        "Liverpool",
        "Edinburgh",
      ],
    },
    {
      "name": "United Arab Emirates",
      "code": "ae",
      "phoneCode": "+971",
      "flag": "🇦🇪",
      "cities": ["Dubai", "Abu Dhabi", "Sharjah", "Al Ain", "Ajman"],
    },
    {
      "name": "India",
      "code": "in",
      "phoneCode": "+91",
      "flag": "🇮🇳",
      "cities": ["Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai"],
    },
    {
      "name": "Canada",
      "code": "ca",
      "phoneCode": "+1",
      "flag": "🇨🇦",
      "cities": ["Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa"],
    },
    {
      "name": "Australia",
      "code": "au",
      "phoneCode": "+61",
      "flag": "🇦🇺",
      "cities": ["Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide"],
    },
    {
      "name": "Germany",
      "code": "de",
      "phoneCode": "+49",
      "flag": "🇩🇪",
      "cities": ["Berlin", "Munich", "Hamburg", "Cologne", "Frankfurt"],
    },
    {
      "name": "France",
      "code": "fr",
      "phoneCode": "+33",
      "flag": "🇫🇷",
      "cities": ["Paris", "Lyon", "Marseille", "Toulouse", "Nice"],
    },
    {
      "name": "China",
      "code": "cn",
      "phoneCode": "+86",
      "flag": "🇨🇳",
      "cities": ["Beijing", "Shanghai", "Guangzhou", "Shenzhen", "Chengdu"],
    },
    {
      "name": "Bangladesh",
      "code": "bd",
      "phoneCode": "+880",
      "flag": "🇧🇩",
      "cities": ["Dhaka", "Chittagong", "Sylhet", "Rajshahi", "Khulna"],
    },
    {
      "name": "Pakistan",
      "code": "pk",
      "phoneCode": "+92",
      "flag": "🇵🇰",
      "cities": ["Karachi", "Lahore", "Islamabad", "Faisalabad", "Rawalpindi"],
    },
    {
      "name": "Philippines",
      "code": "ph",
      "phoneCode": "+63",
      "flag": "🇵🇭",
      "cities": ["Manila", "Cebu City", "Davao", "Quezon City", "Makati"],
    },
    {
      "name": "Vietnam",
      "code": "vn",
      "phoneCode": "+84",
      "flag": "🇻🇳",
      "cities": [
        "Ho Chi Minh City",
        "Hanoi",
        "Da Nang",
        "Hai Phong",
        "Can Tho",
      ],
    },
    {
      "name": "Nigeria",
      "code": "ng",
      "phoneCode": "+234",
      "flag": "🇳🇬",
      "cities": ["Lagos", "Abuja", "Kano", "Ibadan", "Port Harcourt"],
    },
    {
      "name": "Saudi Arabia",
      "code": "sa",
      "phoneCode": "+966",
      "flag": "🇸🇦",
      "cities": ["Riyadh", "Jeddah", "Mecca", "Medina", "Dammam"],
    },
    {
      "name": "Qatar",
      "code": "qa",
      "phoneCode": "+974",
      "flag": "🇶🇦",
      "cities": ["Doha", "Al Rayyan", "Umm Salal", "Al Wakrah", "Al Khor"],
    },
    {
      "name": "Italy",
      "code": "it",
      "phoneCode": "+39",
      "flag": "🇮🇹",
      "cities": ["Rome", "Milan", "Naples", "Turin", "Florence"],
    },
    {
      "name": "Japan",
      "code": "jp",
      "phoneCode": "+81",
      "flag": "🇯🇵",
      "cities": ["Tokyo", "Osaka", "Kyoto", "Yokohama", "Nagoya"],
    },
    {
      "name": "South Korea",
      "code": "kr",
      "phoneCode": "+82",
      "flag": "🇰🇷",
      "cities": ["Seoul", "Busan", "Incheon", "Daegu", "Daejeon"],
    },
    {
      "name": "Singapore",
      "code": "sg",
      "phoneCode": "+65",
      "flag": "🇸🇬",
      "cities": ["Singapore", "Jurong", "Tampines", "Woodlands", "Bedok"],
    },
    {
      "name": "Turkey",
      "code": "tr",
      "phoneCode": "+90",
      "flag": "🇹🇷",
      "cities": ["Istanbul", "Ankara", "Izmir", "Bursa", "Antalya"],
    },
    {
      "name": "Romania",
      "code": "ro",
      "phoneCode": "+40",
      "flag": "🇷🇴",
      "cities": ["Bucharest", "Cluj-Napoca", "Timișoara", "Iași", "Constanța"],
    },
  ];
}
