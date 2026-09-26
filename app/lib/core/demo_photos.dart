// Photos of the demo cars from Wikimedia Commons. Each file is free to
// reuse under the Creative Commons licence shown, with credit to its
// author (named on the file page linked in the app's photo credits).

class PhotoCredit {
  const PhotoCredit(this.file, this.license);

  /// File name on Wikimedia Commons.
  final String file;
  final String license;

  String get _name => file.replaceAll(' ', '_');

  /// The file's page, with author and licence details.
  String get pageUrl =>
      'https://commons.wikimedia.org/wiki/File:${Uri.encodeComponent(_name)}';
}

/// 960 px wide copies served by Wikimedia (paths use the md5 of the name).
const demoCarPhotos = <String, (String, PhotoCredit)>{
  'car-1': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/VW_Golf_1.4_TSI_BlueMotion_Technology_CUP_%28VII%29_%E2%80%93_Frontansicht%2C_15._Juni_2014%2C_D%C3%BCsseldorf.jpg/960px-VW_Golf_1.4_TSI_BlueMotion_Technology_CUP_%28VII%29_%E2%80%93_Frontansicht%2C_15._Juni_2014%2C_D%C3%BCsseldorf.jpg',
    PhotoCredit(
      'VW Golf 1.4 TSI BlueMotion Technology CUP (VII) – Frontansicht, 15. Juni 2014, Düsseldorf.jpg',
      'CC BY-SA',
    ),
  ),
  'car-2': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Toyota_Yaris_Hybrid_%28XP210%29_1X7A0353.jpg/960px-Toyota_Yaris_Hybrid_%28XP210%29_1X7A0353.jpg',
    PhotoCredit('Toyota Yaris Hybrid (XP210) 1X7A0353.jpg', 'CC BY-SA'),
  ),
  'car-3': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/2016_Fiat_500_Lounge_1.2_Front.jpg/960px-2016_Fiat_500_Lounge_1.2_Front.jpg',
    PhotoCredit('2016 Fiat 500 Lounge 1.2 Front.jpg', 'CC BY-SA'),
  ),
  'car-4': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/Skoda_Octavia_Combi_RS_%28III%29_%E2%80%93_Frontansicht%2C_20._Juni_2014%2C_D%C3%BCsseldorf.jpg/960px-Skoda_Octavia_Combi_RS_%28III%29_%E2%80%93_Frontansicht%2C_20._Juni_2014%2C_D%C3%BCsseldorf.jpg',
    PhotoCredit(
      'Skoda Octavia Combi RS (III) – Frontansicht, 20. Juni 2014, Düsseldorf.jpg',
      'CC BY-SA',
    ),
  ),
  'car-5': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f1/Hyundai_Tucson_%28NX4%29_1X7A0424.jpg/960px-Hyundai_Tucson_%28NX4%29_1X7A0424.jpg',
    PhotoCredit('Hyundai Tucson (NX4) 1X7A0424.jpg', 'CC BY-SA'),
  ),
  'car-6': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/6/63/Toyota_RAV4_%28XA50%29_IMG_1998.jpg/960px-Toyota_RAV4_%28XA50%29_IMG_1998.jpg',
    PhotoCredit('Toyota RAV4 (XA50) IMG 1998.jpg', 'CC BY-SA'),
  ),
  'car-7': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Dacia_Duster_II_Facelift_IAA_2021_1X7A0132.jpg/960px-Dacia_Duster_II_Facelift_IAA_2021_1X7A0132.jpg',
    PhotoCredit('Dacia Duster II Facelift IAA 2021 1X7A0132.jpg', 'CC BY-SA'),
  ),
  'car-8': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Mercedes-Benz_W213_Facelift_IMG_3726.jpg/960px-Mercedes-Benz_W213_Facelift_IMG_3726.jpg',
    PhotoCredit('Mercedes-Benz W213 Facelift IMG 3726.jpg', 'CC BY-SA'),
  ),
  'car-9': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ac/BMW_G05_IMG_2670.jpg/960px-BMW_G05_IMG_2670.jpg',
    PhotoCredit('BMW G05 IMG 2670.jpg', 'CC BY-SA'),
  ),
  'car-10': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/1/17/Mercedes-Benz_Vito_Tourer_W447_Vorderansicht.jpg/960px-Mercedes-Benz_Vito_Tourer_W447_Vorderansicht.jpg',
    PhotoCredit('Mercedes-Benz Vito Tourer W447 Vorderansicht.jpg', 'CC BY-SA'),
  ),
  'car-11': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Opel_Corsa_1.4_Turbo_ecoFLEX_Color_Edition_%28E%29_%E2%80%93_Frontansicht%2C_24._Oktober_2015%2C_M%C3%BCnster.jpg/960px-Opel_Corsa_1.4_Turbo_ecoFLEX_Color_Edition_%28E%29_%E2%80%93_Frontansicht%2C_24._Oktober_2015%2C_M%C3%BCnster.jpg',
    PhotoCredit(
      'Opel Corsa 1.4 Turbo ecoFLEX Color Edition (E) – Frontansicht, 24. Oktober 2015, Münster.jpg',
      'CC BY-SA',
    ),
  ),
  'car-12': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Kia_Sportage_%28NQ5%29_1X7A0326.jpg/960px-Kia_Sportage_%28NQ5%29_1X7A0326.jpg',
    PhotoCredit('Kia Sportage (NQ5) 1X7A0326.jpg', 'CC BY-SA'),
  ),
  'car-13': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Renault_Clio_V_1X7A0309.jpg/960px-Renault_Clio_V_1X7A0309.jpg',
    PhotoCredit('Renault Clio V 1X7A0309.jpg', 'CC BY-SA'),
  ),
  'car-14': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Jeep_Renegade_2.0_MultiJet_4x4_Trailhawk_%28Facelift%29_%E2%80%93_f_02042021.jpg/960px-Jeep_Renegade_2.0_MultiJet_4x4_Trailhawk_%28Facelift%29_%E2%80%93_f_02042021.jpg',
    PhotoCredit(
      'Jeep Renegade 2.0 MultiJet 4x4 Trailhawk (Facelift) – f 02042021.jpg',
      'CC BY-SA',
    ),
  ),
  'car-15': (
    'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d2/2018_Fiat_Panda_Easy_1.2.jpg/960px-2018_Fiat_Panda_Easy_1.2.jpg',
    PhotoCredit('2018 Fiat Panda Easy 1.2.jpg', 'CC BY-SA'),
  ),
};

/// The credit for a demo photo URL, or null for owners' own photos.
PhotoCredit? creditFor(String url) {
  for (final (u, credit) in demoCarPhotos.values) {
    if (u == url) return credit;
  }
  return null;
}
