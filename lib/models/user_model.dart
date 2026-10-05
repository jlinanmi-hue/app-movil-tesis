class UserModel {
  final String usuarioId;
  final String userName;
  final String? rol;
  final EmpleadoModel? empleado;
  final String? token;

  UserModel({
    required this.usuarioId,
    required this.userName,
    this.rol,
    this.empleado,
    this.token,
  });

  UserModel copyWith({
    String? usuarioId,
    String? userName,
    String? rol,
    EmpleadoModel? empleado,
    String? token,
  }) {
    return UserModel(
      usuarioId: usuarioId ?? this.usuarioId,
      userName: userName ?? this.userName,
      rol: rol ?? this.rol,
      empleado: empleado ?? this.empleado,
      token: token ?? this.token,
    );
  }

  String get nombreCompleto {
    if (empleado != null && empleado!.nombres.isNotEmpty) {
      return '${empleado!.nombres} ${empleado!.apellidos}'.trim();
    }
    return userName;
  }

  String get cargo => empleado?.cargo ?? 'Personal Autorizado';

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    final userObj = json['usuario'] as Map<String, dynamic>? ?? json;
    final empObj = json['empleado'] as Map<String, dynamic>?;

    return UserModel(
      usuarioId: (userObj['UsuarioId'] ?? userObj['id'] ?? '').toString(),
      userName: (userObj['UsuarioUserName'] ?? userObj['username'] ?? 'admin').toString(),
      rol: userObj['rol']?.toString(),
      empleado: empObj != null ? EmpleadoModel.fromJson(empObj) : null,
      token: token ?? json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario': {
        'UsuarioId': usuarioId,
        'UsuarioUserName': userName,
        'rol': rol,
      },
      if (empleado != null) 'empleado': empleado!.toJson(),
      if (token != null) 'token': token,
    };
  }
}

class EmpleadoModel {
  final String id;
  final String nombres;
  final String apellidos;
  final String correo;
  final String? dni;
  final String? telefono;
  final String? sexo;
  final String? direccion;
  final String? fechaIngreso;
  final String? cargo;
  final String? estado;

  EmpleadoModel({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    this.dni,
    this.telefono,
    this.sexo,
    this.direccion,
    this.fechaIngreso,
    this.cargo,
    this.estado,
  });

  EmpleadoModel copyWith({
    String? id,
    String? nombres,
    String? apellidos,
    String? correo,
    String? dni,
    String? telefono,
    String? sexo,
    String? direccion,
    String? fechaIngreso,
    String? cargo,
    String? estado,
  }) {
    return EmpleadoModel(
      id: id ?? this.id,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      correo: correo ?? this.correo,
      dni: dni ?? this.dni,
      telefono: telefono ?? this.telefono,
      sexo: sexo ?? this.sexo,
      direccion: direccion ?? this.direccion,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      cargo: cargo ?? this.cargo,
      estado: estado ?? this.estado,
    );
  }

  factory EmpleadoModel.fromJson(Map<String, dynamic> json) {
    return EmpleadoModel(
      id: (json['EmpleadoId'] ?? json['id'] ?? '').toString(),
      nombres: (json['EmpleadoNombres'] ?? json['nombres'] ?? '').toString(),
      apellidos: (json['EmpleadoApellidos'] ?? json['apellidos'] ?? '').toString(),
      correo: (json['EmpleadoCorreo'] ?? json['correo'] ?? '').toString(),
      dni: (json['EmpleadoDni'] ?? json['dni'])?.toString(),
      telefono: (json['EmpleadoTelefono'] ?? json['telefono'])?.toString(),
      sexo: (json['EmpleadoSexo'] ?? json['sexo'])?.toString(),
      direccion: (json['EmpleadoDireccion'] ?? json['direccion'])?.toString(),
      fechaIngreso: (json['EmpleadoFechaIngreso'] ?? json['fecha_ingreso'])?.toString(),
      cargo: (json['cargoNombre'] ??
              (json['cargo'] is Map ? json['cargo']['cargoDescripcion'] : json['cargo']))
          ?.toString(),
      estado: (json['EmpleadoEstado'] ?? json['estado'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'EmpleadoId': id,
      'EmpleadoNombres': nombres,
      'EmpleadoApellidos': apellidos,
      'EmpleadoCorreo': correo,
      if (dni != null) 'EmpleadoDni': dni,
      if (telefono != null) 'EmpleadoTelefono': telefono,
      if (sexo != null) 'EmpleadoSexo': sexo,
      if (direccion != null) 'EmpleadoDireccion': direccion,
      if (fechaIngreso != null) 'EmpleadoFechaIngreso': fechaIngreso,
      if (cargo != null) 'cargo': cargo,
      if (estado != null) 'estado': estado,
    };
  }
}
