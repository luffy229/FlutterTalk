import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:messenger_app/data/models/user_model.dart';
import 'package:messenger_app/data/services/base_repository.dart';

class ContactRepository extends BaseRepository {
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<bool> requestContactsPermission() async {
    return await FlutterContacts.requestPermission();
  }

  Future<List<Map<String, dynamic>>> getRegisteredContacts() async {
    try {
      //get device contacts with phone number
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      //extract phone numbers and normalize them
      final phoneNumbers =
          contacts
              .where((contact) => contact.phones.isNotEmpty)
              .map(
                (contact) => {
                  'name': contact.displayName,
                  'phoneNumber': contact.phones.first.number.replaceAll(
                    RegExp(r'[^\d+]'),
                    '',
                  ),
                  'photo': contact.photo,
                },
              )
              .toList();

      //get all users from firestore

      final usersSnapshot = await firestore.collection("users").get();

      final registeredUsers =
          usersSnapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

      // match contacts with registered users

      final matchedContacts =
          phoneNumbers
              .where((contact) {
                final phoneNumber = contact["phoneNumber"];
                return registeredUsers.any(
                  (user) =>
                      user.phoneNumber == phoneNumber &&
                      user.uid != currentUserId,
                );
              })
              .map((contact) {
                final registeredUser = registeredUsers.firstWhere(
                  (user) => user.phoneNumber == contact["phoneNumber"],
                );
                return {
                  'id': registeredUser.uid,
                  'name': contact['name'],
                  'phoneNumber': contact['phoneNumber'],
                };
              })
              .toList();

      return matchedContacts;
    } catch (e) {
      print("error getting registered users");
      return [];
    }
  }
}
