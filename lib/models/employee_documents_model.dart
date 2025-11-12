class EmployeeDocuments {
  final int id;
  final String? tenth;
  final String? twelth;
  final String? resume;
  final String? degree;
  final String? idProof;
  final String? marksCard;
  final String? award;
  final String? certificates;
  final String? masters;
  final String? appointmentLetter;
  final String? offerLetter;
  final String? releavingLetter;
  final String? resignationLetter;
  final String? achievementCrt;
  final String? bonafideCrt;

  EmployeeDocuments({
    required this.id,
    this.tenth,
    this.twelth,
    this.resume,
    this.degree,
    this.idProof,
    this.marksCard,
    this.award,
    this.certificates,
    this.masters,
    this.appointmentLetter,
    this.offerLetter,
    this.releavingLetter,
    this.resignationLetter,
    this.achievementCrt,
    this.bonafideCrt,
  });

  factory EmployeeDocuments.fromJson(Map<String, dynamic> json) {
    return EmployeeDocuments(
      id: json['id'] ?? 0,
      tenth: json['tenth'],
      twelth: json['twelth'],
      resume: json['resume'],
      degree: json['degree'],
      idProof: json['id_proof'],
      marksCard: json['marks_card'],
      award: json['award'],
      certificates: json['certificates'],
      masters: json['masters'],
      appointmentLetter: json['appointment_letter'],
      offerLetter: json['offer_letter'],
      releavingLetter: json['releaving_letter'],
      resignationLetter: json['resignation_letter'],
      achievementCrt: json['achievement_crt'],
      bonafideCrt: json['bonafide_crt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenth': tenth,
      'twelth': twelth,
      'resume': resume,
      'degree': degree,
      'id_proof': idProof,
      'marks_card': marksCard,
      'award': award,
      'certificates': certificates,
      'masters': masters,
      'appointment_letter': appointmentLetter,
      'offer_letter': offerLetter,
      'releaving_letter': releavingLetter,
      'resignation_letter': resignationLetter,
      'achievement_crt': achievementCrt,
      'bonafide_crt': bonafideCrt,
    };
  }

  // Helper method to get all documents as a map
  Map<String, DocumentInfo> getAllDocuments() {
    return {
      '10th Marksheet': DocumentInfo(url: tenth, label: '10th Marksheet'),
      '12th Marksheet': DocumentInfo(url: twelth, label: '12th Marksheet'),
      'Resume': DocumentInfo(url: resume, label: 'Resume'),
      'Degree Certificate': DocumentInfo(url: degree, label: 'Degree Certificate'),
      'ID Proof': DocumentInfo(url: idProof, label: 'ID Proof'),
      'Marks Card': DocumentInfo(url: marksCard, label: 'Marks Card'),
      'Awards & Certifications': DocumentInfo(url: award, label: 'Awards & Certifications'),
      'Certificates': DocumentInfo(url: certificates, label: 'Certificates'),
      'Masters Certificate': DocumentInfo(url: masters, label: 'Masters Certificate'),
      'Appointment Letter': DocumentInfo(url: appointmentLetter, label: 'Appointment Letter'),
      'Offer Letter': DocumentInfo(url: offerLetter, label: 'Offer Letter'),
      'Releaving Letter': DocumentInfo(url: releavingLetter, label: 'Releaving Letter'),
      'Resignation Letter': DocumentInfo(url: resignationLetter, label: 'Resignation Letter'),
      'Achievement Certificate': DocumentInfo(url: achievementCrt, label: 'Achievement Certificate'),
      'Bonafide Certificate': DocumentInfo(url: bonafideCrt, label: 'Bonafide Certificate'),
    };
  }
}

class DocumentInfo {
  final String? url;
  final String label;

  DocumentInfo({required this.url, required this.label});

  bool get isAvailable => url != null && url!.isNotEmpty;
}
