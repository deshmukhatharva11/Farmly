import '../models/disease.dart';

class MockDiseases {
  static const List<Disease> diseases = [
    Disease(
      id: 'leaf_spot',
      name: 'Leaf Spot',
      nameMarathi: 'पानावरील डाग',
      nameHindi: 'पत्ती धब्बा',
      description: 'Leaf spot is a common fungal disease causing circular brown spots on leaves. It spreads in warm, humid conditions typical of Maharashtra monsoon season.',
      descriptionMarathi: 'पानावरील डाग हा सामान्य बुरशीजन्य रोग आहे ज्यामुळे पानांवर गोलाकार तपकिरी डाग पडतात. महाराष्ट्रातील पावसाळ्यातील उबदार, दमट हवामानात हा पसरतो.',
      descriptionHindi: 'पत्ती धब्बा एक सामान्य कवक रोग है जो पत्तियों पर गोलाकार भूरे धब्बे बनाता है। यह महाराष्ट्र के मानसून मौसम की गर्म, नम स्थितियों में फैलता है।',
      causes: ['Fungal infection (Cercospora)', 'High humidity (>80%)', 'Poor ventilation', 'Overhead irrigation'],
      causesMarathi: ['बुरशी संसर्ग (सर्कोस्पोरा)', 'जास्त आर्द्रता (>८०%)', 'खराब हवा खेळणे', 'वरून पाणी देणे'],
      symptoms: ['Circular brown spots on leaves', 'Yellow halo around spots', 'Premature leaf drop', 'Reduced yield'],
      symptomsMarathi: ['पानांवर गोलाकार तपकिरी डाग', 'डागांभोवती पिवळी कड', 'पाने लवकर गळणे', 'उत्पादन कमी होणे'],
      treatments: ['Apply Mancozeb 75% WP at 2.5g/litre', 'Remove and destroy infected leaves', 'Ensure proper plant spacing', 'Use drip irrigation instead of overhead'],
      treatmentsMarathi: ['मॅन्कोझेब ७५% WP प्रति लिटर २.५ ग्रॅम फवारा', 'संक्रमित पाने काढून नष्ट करा', 'योग्य अंतर ठेवा', 'वरून पाणी देण्याऐवजी ठिबक सिंचन वापरा'],
      prevention: ['Use disease-resistant varieties', 'Maintain proper spacing', 'Avoid working in wet fields', 'Crop rotation every season'],
      preventionMarathi: ['रोग प्रतिकारक वाण वापरा', 'योग्य अंतर ठेवा', 'ओल्या शेतात काम टाळा', 'दर हंगामात पीक फेरपालट करा'],
      severity: 'Medium',
      affectedCrops: 'Cotton, Soybean, Sugarcane',
    ),
    Disease(
      id: 'powdery_mildew',
      name: 'Powdery Mildew',
      nameMarathi: 'भुरी',
      nameHindi: 'चूर्णिल आसिता',
      description: 'Powdery mildew appears as white powdery coating on leaves. Common in Maharashtra during winter months in crops like grape, mango, and vegetables.',
      descriptionMarathi: 'भुरी म्हणजे पानांवर पांढरा भुकटीसारखा थर. महाराष्ट्रात हिवाळ्यात द्राक्ष, आंबा आणि भाज्यांमध्ये हा सामान्य आहे.',
      descriptionHindi: 'चूर्णिल आसिता पत्तियों पर सफेद चूर्ण के रूप में दिखाई देती है। महाराष्ट्र में सर्दियों के महीनों में अंगूर, आम और सब्जियों में आम है।',
      causes: ['Fungal spores (Erysiphe)', 'Cool dry weather 20-25°C', 'Poor air circulation', 'Dense planting'],
      causesMarathi: ['बुरशी बीजाणू (एरीसाईफी)', 'थंड कोरडे हवामान २०-२५°C', 'कमी हवा खेळणे', 'दाट लागवड'],
      symptoms: ['White powdery patches on leaves', 'Leaf curling', 'Stunted growth', 'Flower/fruit drop'],
      symptomsMarathi: ['पानांवर पांढरे भुकटीसारखे डाग', 'पाने गुंडाळणे', 'वाढ खुंटणे', 'फुले/फळे गळणे'],
      treatments: ['Spray wettable sulfur 3g/litre', 'Apply neem oil 5ml/litre', 'Use Carbendazim 1g/litre', 'Spray milk solution (1:9 ratio)'],
      treatmentsMarathi: ['ओलावायोग्य गंधक ३ ग्रॅम/लिटर फवारा', 'कडुलिंब तेल ५ मिली/लिटर वापरा', 'कार्बेन्डाझिम १ ग्रॅम/लिटर वापरा', 'दूध द्रावण (१:९) फवारा'],
      prevention: ['Plant resistant varieties', 'Avoid dense planting', 'Ensure good air flow', 'Regular monitoring'],
      preventionMarathi: ['प्रतिकारक वाण लावा', 'दाट लागवड टाळा', 'चांगली हवा खेळू द्या', 'नियमित तपासणी करा'],
      severity: 'High',
      affectedCrops: 'Grape, Mango, Vegetables',
    ),
    Disease(
      id: 'rust',
      name: 'Rust',
      nameMarathi: 'गंज रोग',
      nameHindi: 'रतुआ रोग',
      description: 'Rust disease causes orange-brown pustules on leaf undersides. Particularly damaging to soybean and sugarcane crops in Vidarbha and Marathwada regions.',
      descriptionMarathi: 'गंज रोगामुळे पानांच्या खालच्या बाजूला नारिंगी-तपकिरी गाठी येतात. विदर्भ आणि मराठवाडा भागातील सोयाबीन आणि ऊस पिकांना विशेष हानिकारक.',
      descriptionHindi: 'रतुआ रोग पत्ती के निचले हिस्से पर नारंगी-भूरे दाने बनाता है। विदर्भ और मराठवाड़ा क्षेत्रों में सोयाबीन और गन्ने की फसलों के लिए विशेष रूप से हानिकारक।',
      causes: ['Fungal pathogen (Puccinia)', 'Warm humid weather', 'Wind-borne spores', 'Continuous cropping'],
      causesMarathi: ['बुरशी (पक्सीनिया)', 'उबदार दमट हवामान', 'वाऱ्याने पसरणारे बीजाणू', 'सतत एकच पीक घेणे'],
      symptoms: ['Orange-brown pustules on leaves', 'Yellow leaf spots', 'Premature drying', 'Significant yield loss'],
      symptomsMarathi: ['पानांवर नारिंगी-तपकिरी गाठी', 'पिवळे डाग', 'अकाली सुकणे', 'उत्पादनात मोठी घट'],
      treatments: ['Apply Propiconazole 25% EC 1ml/litre', 'Spray Hexaconazole 5% EC', 'Remove heavily infected plants', 'Apply potash fertilizer'],
      treatmentsMarathi: ['प्रोपिकोनाझोल २५% EC १ मिली/लिटर फवारा', 'हेक्साकोनाझोल ५% EC फवारा', 'जास्त संक्रमित रोपे काढा', 'पोटॅश खत वापरा'],
      prevention: ['Use resistant seed varieties', 'Crop rotation', 'Early sowing', 'Balanced fertilization'],
      preventionMarathi: ['प्रतिकारक बियाणे वापरा', 'पीक फेरपालट करा', 'लवकर पेरणी करा', 'संतुलित खत वापरा'],
      severity: 'High',
      affectedCrops: 'Soybean, Sugarcane, Wheat',
    ),
  ];

  static Disease getDiseaseByName(String name) {
    return diseases.firstWhere(
      (d) => d.name.toLowerCase() == name.toLowerCase(),
      orElse: () => diseases.first,
    );
  }
}
