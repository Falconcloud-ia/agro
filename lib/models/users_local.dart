class UsuarioLocal {
  final String uid;
  final String email;
  final String rol;
  final String nombre;
  final String ciudad;
  final String password; // ✅ nuevo campo agregado

  UsuarioLocal({
    required this.uid,
    required this.email,
    required this.rol,
    required this.nombre,
    required this.ciudad,
    required this.password, // ✅ incluir en el constructor
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'rol': rol,
    'nombre': nombre,
    'ciudad': ciudad,
    'password': password, // ✅ incluir en el mapa
  };

  static UsuarioLocal fromMap(Map<String, dynamic> map) => UsuarioLocal(
    uid: map['uid'],
    email: map['email'],
    rol: map['rol'],
    nombre: map['nombre'],
    ciudad: map['ciudad'],
    password: map['password'], // ✅ incluir al reconstruir
  );
}
