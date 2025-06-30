/// Callback que se ejecuta desde un `AlarmManager` en Android.
///
/// Este código es invocado incluso si la aplicación no está en primer plano,
/// por lo que simplemente imprime un mensaje para efectos de depuración.
void backgroundCallbackDispatcher() {
  print('Ejecutando proceso batch');
}

