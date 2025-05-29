import 'package:flutter/material.dart';

class SemesterSelector extends StatelessWidget {
  final int currentYear;
  final int currentSemester;
  final String currentMajor;
  final Function(int) onYearChanged;
  final Function(int) onSemesterChanged;
  final Function(String) onMajorChanged;

  const SemesterSelector({
    Key? key,
    required this.currentYear,
    required this.currentSemester,
    required this.currentMajor,
    required this.onYearChanged,
    required this.onSemesterChanged,
    required this.onMajorChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // List of majors
    final List<String> majors = [
      'حواسيب',
      'اتصالات',
      'ميكاترونيك',
      'تحكم',
      'قدرة',
      'قيادة',
      'الكترونية'
    ];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_outlined,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'اختر التخصص والمستوى',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Major Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التخصص',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.grey[50],
                ),
                child: DropdownButtonFormField<String>(
                  hint: Text(
                    "اختر القسم",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  value: currentMajor == "" ? null : currentMajor,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.school_outlined,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                  ),
                  dropdownColor: Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[600],
                  ),
                  items: majors.map((major) {
                    return DropdownMenuItem<String>(
                      value: major,
                      child: Text(
                        major,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onMajorChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          Row(
            children: [
              // Year Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السنة الدراسية',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        color: Colors.grey[50],
                      ),
                      child: DropdownButtonFormField<int>(
                        value: currentYear,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.grey[500],
                            size: 18,
                          ),
                        ),
                        dropdownColor: Colors.white,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[600],
                        ),
                        items: [1, 2, 3, 4, 5].map((year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              'السنة $year',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            onYearChanged(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 16),

              // Semester Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الفصل الدراسي',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        color: Colors.grey[50],
                      ),
                      child: DropdownButtonFormField<int>(
                        value: currentSemester,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.event_note_outlined,
                            color: Colors.grey[500],
                            size: 18,
                          ),
                        ),
                        dropdownColor: Colors.white,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[600],
                        ),
                        items: [1, 2].map((semester) {
                          return DropdownMenuItem<int>(
                            value: semester,
                            child: Text(
                              'الفصل $semester',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            onSemesterChanged(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}