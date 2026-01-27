import chardet

def check_encoding(file_path):
    with open(file_path, 'rb') as f:
        raw_data = f.read()
        result = chardet.detect(raw_data)
        print(f"File: {file_path}")
        print(f"Encoding: {result['encoding']}")
        print(f"Confidence: {result['confidence']}")

check_encoding(r'c:\Users\Bojan\gavra_android\lib\screens\registrovani_putnik_profil_screen.dart')
check_encoding(r'c:\Users\Bojan\gavra_android\lib\services\finansije_service.dart')
