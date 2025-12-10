## लक्ष्य
- बॉटम नेव में ऑर्डर: Home → Location → 4 छोटे कार्ड्स → Search.
- सिस्टम की बॉटम बार के ऊपर दिखे, छिपे नहीं.
- नेव बार की कुल ऊंचाई थोड़ी कम करें.

## प्रभावित फ़ाइल
- `lib/screens/home_screen.dart`

## आइटम ऑर्डर बदलाव
- रेंडर ऑर्डर अपडेट करें:
  - बाएं: `Home` (जैसा है) `home_screen.dart:909`.
  - उसके बाद: `Location` आइकन (उदा. `Icons.location_on_outlined`) — वर्तमान `Search` कॉल को बदलें `home_screen.dart:910–911`.
  - बीच वाला तीसरा: `Cards` आइटम (उदा. `Icons.grid_view`) — मौजूदा राइट साइड के पहले आइटम की जगह `home_screen.dart:921`.
  - सबसे दायां: `Search` — मौजूदा राइट साइड के दूसरे आइटम की जगह `home_screen.dart:922–923`.
- यदि केवल 4 टैब रखने हैं तो `favorite`/`person` संबंधित कोड हटाएँ और `_selectedIndex` मैपिंग व पेज स्विचिंग को 4 के अनुरूप करें.

## पेज स्विचिंग अपडेट
- `_buildPageContent()` के `switch(_selectedIndex)` को 4 केस में अपडेट करें `home_screen.dart:934–959`:
  - `0: Home`
  - `1: Location`
  - `2: Cards` (4 छोटे कार्ड्स का व्यू)
  - `3: Search`

## सिस्टम इनसेट/सेफ़ एरिया फिक्स
- बॉटम नेव को सिस्टम नेव बार के ऊपर लाने के लिए:
  - `bottomNavigationBar` कंटेनर को `SafeArea(bottom: true, minimum: EdgeInsets.only(bottom: 6))` से रैप करें `home_screen.dart:883–901`.
  - वैकल्पिक/कम कंट्रोल: कंटेनर में `padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom)` जोड़ें और `margin.vertical` घटाएँ ताकि कुल ऊंचाई न बढ़े.
  - जरूरत हो तो `Scaffold(extendBody: true)` सेट करें ताकि नेवबार बैकग्राउंड ब्लर/पेंट सही दिखे.

## हाइट/स्टाइल छोटा करना
- कंटेनर `height: 70` को `56–60` करें `home_screen.dart:884`.
- `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12)` को `vertical: 8–10` करें `home_screen.dart:885`.
- आइकॉन साइज `22` → `20` `home_screen.dart:1173`.
- लेबल फॉन्ट साइज `11` → `10` `home_screen.dart:1179–1182`.
- `borderRadius: BorderRadius.circular(35)` को `30` करें `home_screen.dart:888, 898`.
- यदि FAB के लिए स्पेस है तो `SizedBox(width: 100)` को छोटा करें `home_screen.dart:915`.

## वेरिफिकेशन
- Android डिवाइस/इम्युलेटर पर जेस्चर और 3-बटन नेव दोनों में टेस्ट करें कि नेवबार सिस्टम बॉटम बार के ऊपर दिखता है.
- कीबोर्ड ओपन होने पर क्लिपिंग न हो (SafeArea/`viewInsets` से मिलकर काम करेगा `home_screen.dart:99, 113, 368`).
- आइटम ऑर्डर: बाएं से दाएं Home, Location, Cards, Search.

कन्फर्म करें तो मैं ये बदलाव लागू कर दूँगा और रन करके विजुअल वेरिफिकेशन भी करूँगा.