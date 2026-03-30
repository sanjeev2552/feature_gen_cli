/// Minimal sample to show CLI usage in a Dart-friendly format.
void main() {
  print("Run this in terminal");
  print("dart pub global activate feature_gen_cli");

  // Run following command to generate single repsonse feature
  print("feature_gen_cli user example/user_schema_single_response.json");

  // Run following command to generate multi response feature
  print("feature_gen_cli user example/user_schema_multi_response.json");
}
