// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get error => 'Erro';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get back => 'Voltar';

  @override
  String get requiredField => 'Este campo é obrigatório';

  @override
  String get invalidUrl => 'Por favor, insira um URL válido';

  @override
  String get loginTitle => 'Login';

  @override
  String get login => 'Entrar';

  @override
  String get logout => 'Sair';

  @override
  String get logoutConfirmTitle => 'Sair';

  @override
  String get logoutConfirmMessage => 'Tem certeza que deseja sair?';

  @override
  String get logoutServerFailedWarning =>
      'Não foi possível sair do servidor, mas saiu localmente';

  @override
  String get retry => 'Tentar Novamente';

  @override
  String get ssoWebViewTitle => 'Entrar';

  @override
  String get ssoCancel => 'Cancelar';

  @override
  String ssoSignInWith(String provider) {
    return 'Entrar com $provider';
  }

  @override
  String get ssoOrDivider => 'OU';

  @override
  String get next => 'Próximo';

  @override
  String get username => 'Nome de utilizador';

  @override
  String get usernameHint => 'Insira o seu nome de utilizador';

  @override
  String get password => 'Palavra-passe';

  @override
  String get passwordHint => 'Insira a sua palavra-passe';

  @override
  String get showPassword => 'Mostrar senha';

  @override
  String get mfaTitle => 'Autenticação de Dois Fatores';

  @override
  String get mfaCode => 'Código MFA';

  @override
  String get mfaCodeHint => 'Insira o código de 6 dígitos';

  @override
  String get mfaCodeRequired => 'Por favor, insira o código MFA';

  @override
  String get verify => 'Verificar';

  @override
  String get mapTab => 'Mapa';

  @override
  String get activitiesTab => 'Atividades';

  @override
  String get settingsTab => 'Configurações';

  @override
  String get settingsScreen => 'Configurações';

  @override
  String get serverSettings => 'Servidor';

  @override
  String get serverSettingsTitle => 'Definições do servidor';

  @override
  String get loggedIn => 'Autenticado';

  @override
  String get serverUrl => 'URL do servidor';

  @override
  String get serverUrlHint => 'https://example.com';

  @override
  String get tileServerUrl => 'URL do servidor de mapas';

  @override
  String get tileServerUrlHint => 'https://tile.openstreetmap.org/...';

  @override
  String get savedSuccessfully => 'Definições guardadas com sucesso';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Padrão do sistema';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageRussian => 'Russo';

  @override
  String get activitiesTitle => 'Atividades';

  @override
  String get activityDetailsTitle => 'Detalhes da atividade';

  @override
  String get activityType => 'Tipo';

  @override
  String get activityDistance => 'Distância';

  @override
  String get activityDuration => 'Duração';

  @override
  String get activityPoints => 'Pontos GPS';

  @override
  String get activityUploadStatus => 'Estado do envio';

  @override
  String get activityKindRunning => 'Corrida';

  @override
  String get activityKindCycling => 'Ciclismo';

  @override
  String get activityKindWalking => 'Caminhada';

  @override
  String get activityKindHiking => 'Trilho';

  @override
  String get activityKindWorkout => 'Treino';

  @override
  String get uploadStatusPending => 'Pendente';

  @override
  String get uploadStatusUploaded => 'Enviado';

  @override
  String get uploadStatusFailed => 'Falhou';

  @override
  String get importGpx => 'Importar GPX';

  @override
  String get importFailed => 'Falha na importação';

  @override
  String get exportFailed => 'Falha na exportação';

  @override
  String get uploadFailed => 'Falha no envio';

  @override
  String get activityUploaded => 'Atividade enviada';

  @override
  String get noActivitiesYet => 'Sem atividades ainda';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Apagar';

  @override
  String get upload => 'Enviar';

  @override
  String get exportGpx => 'Exportar GPX';

  @override
  String get editActivityTitle => 'Editar atividade';

  @override
  String get deleteActivityTitle => 'Apagar atividade';

  @override
  String get deleteActivityMessage => 'Apagar atividade';

  @override
  String get activityTitle => 'Título';

  @override
  String get activityNotes => 'Notas';

  @override
  String get trackingActive => 'A registar:';

  @override
  String get trackerIdle => 'Rastreador inativo';

  @override
  String get averageSpeed => 'Velocidade média';

  @override
  String get cacheArea => 'Cache';

  @override
  String get selectArea => 'Selecionar área';

  @override
  String get selectAreaEnabled => 'Área selecionada';

  @override
  String get cachedTiles => 'Tiles em cache';

  @override
  String get cacheError => 'Erro de cache';

  @override
  String get start => 'Iniciar';

  @override
  String get stop => 'Parar';

  @override
  String get pause => 'Pausar';

  @override
  String get resume => 'Retomar';

  @override
  String get startActivity => 'Iniciar atividade';

  @override
  String get stopActivity => 'Parar atividade';

  @override
  String get stopActivityConfirm => 'Terminar e guardar a atividade atual?';

  @override
  String get myLocation => 'Minha localização';

  @override
  String get settingsUpdated => 'Definições atualizadas';

  @override
  String get bluetoothSensors => 'Sensores Bluetooth';

  @override
  String get scan => 'Pesquisar';

  @override
  String get savedDevices => 'Dispositivos guardados';

  @override
  String get noSavedSensors => 'Sem sensores guardados';

  @override
  String get nearbyDevices => 'Dispositivos próximos';

  @override
  String get unknownDevice => 'Dispositivo desconhecido';

  @override
  String get add => 'Adicionar';

  @override
  String get appearance => 'Aparência';

  @override
  String get themeMode => 'Modo de tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get gpsTracking => 'GPS e rastreamento';

  @override
  String get gpsAccuracyMode => 'Modo de precisão';

  @override
  String get gpsAccuracyHigh => 'Alta (GPS)';

  @override
  String get gpsAccuracyBalanced => 'Equilibrada (GPS + rede)';

  @override
  String get gpsAccuracyLow => 'Pouca energia';

  @override
  String get minDistanceBetweenPoints => 'Distância mínima entre pontos';

  @override
  String get syncAndCache => 'Sincronização e cache';

  @override
  String get uploadEndpoint => 'Endpoint de envio';

  @override
  String get apiPassword => 'Palavra-passe da API';

  @override
  String get apiPasswordHint =>
      'Insira a palavra-passe da API gerada no servidor';

  @override
  String get mapCacheFolder => 'Pasta de cache de mapa';

  @override
  String get saveTrackingSettings => 'Guardar definições de rastreamento';

  @override
  String get notConfigured => 'Não configurado';

  @override
  String get notLoggedIn => 'Sem sessão iniciada';

  @override
  String get tabRecord => 'Gravar';

  @override
  String get tabHistory => 'Histórico';

  @override
  String get tabGear => 'Equipamento';

  @override
  String get profileTab => 'Perfil';

  @override
  String get themeTab => 'Tema';

  @override
  String get mapSettingsTab => 'Mapa';

  @override
  String get coachTab => 'Treinador';

  @override
  String get systemTab => 'Sistema';

  @override
  String get profileAnonymous => 'Anónimo';

  @override
  String get profilePersonalData => 'Dados pessoais';

  @override
  String get profileHeight => 'Altura (cm)';

  @override
  String get profileWeight => 'Peso (kg)';

  @override
  String get profileCity => 'Cidade';

  @override
  String get profileMaxHr => 'Freq. cardíaca máx.';

  @override
  String get profileGender => 'Género';

  @override
  String get profileMale => 'Masculino';

  @override
  String get profileFemale => 'Feminino';

  @override
  String get profileNA => 'N/D';

  @override
  String get profileLoading => 'A carregar...';

  @override
  String get profileRefresh => 'Atualizar do servidor';

  @override
  String get dynamicColor => 'Cor dinâmica (Android 12+)';

  @override
  String get accentColor => 'Cor de destaque';

  @override
  String get pickColor => 'Escolher cor';

  @override
  String get bgColor => 'Cor de fundo';

  @override
  String get enableGradient => 'Ativar gradiente';

  @override
  String get gradientColor => 'Cor do gradiente';

  @override
  String get topographicMap => 'Mapa topográfico';

  @override
  String get mapTheme => 'Tema do mapa';

  @override
  String get mapThemeAuto => 'Auto';

  @override
  String get mapThemeLight => 'Claro';

  @override
  String get mapThemeDark => 'Escuro';

  @override
  String get matchSystemTheme => 'Seguir tema do sistema';

  @override
  String get mapBehavior => 'Comportamento do mapa durante registo';

  @override
  String get mapBehaviorDesc =>
      'Controla como o mapa reage ao seu movimento durante uma sessão de registo.';

  @override
  String get mapBehaviorOff => 'Desativado';

  @override
  String get mapBehaviorOffDesc => 'Mapa fica parado';

  @override
  String get mapBehaviorFollow => 'Seguir localização';

  @override
  String get mapBehaviorFollowDesc => 'Centrar na posição GPS';

  @override
  String get mapBehaviorFollowHeading => 'Seguir + orientação';

  @override
  String get mapBehaviorFollowHeadingDesc => 'Rodar mapa com bússola';

  @override
  String get gpsAccuracy => 'Precisão';

  @override
  String get distanceFilter => 'Filtro de distância (m)';

  @override
  String get meters => 'metros';

  @override
  String get mapCache => 'Cache do mapa';

  @override
  String get cacheFolder => 'Pasta de cache';

  @override
  String get voiceCoach => 'Treinador de voz';

  @override
  String get voiceGender => 'Género da voz';

  @override
  String get speechRate => 'Velocidade da fala';

  @override
  String get volume => 'Volume';

  @override
  String get twoFactorAuth => 'Autenticação de dois fatores (MFA)';

  @override
  String get mfaSecretHelper =>
      'Chave secreta TOTP para autenticação de dois fatores';

  @override
  String get mfaSecretDesc =>
      'Se tem 2FA ativado na sua conta, guarde o segredo TOTP (do autenticador) aqui para o app gerar códigos de verificação automaticamente.';

  @override
  String get dataUpload => 'Envio de dados';

  @override
  String get clearLocalCache => 'Limpar cache local';

  @override
  String get clearCacheTitle => 'Limpar cache?';

  @override
  String get clearCacheMsg =>
      'Isto irá remover todos os dados de atividades e fitness guardados localmente.';

  @override
  String get clear => 'Limpar';

  @override
  String get searchHint => 'Pesquisar por nome...';

  @override
  String get allTypes => 'Todos os tipos';

  @override
  String get filterByStatus => 'Filtrar por estado';

  @override
  String get allStatuses => 'Todos os estados';

  @override
  String get inCloud => 'Na nuvem';

  @override
  String get pendingUpload => 'Envio pendente';

  @override
  String get uploadError => 'Erro no envio';

  @override
  String get sessionExpired => 'Sessão expirada. Inicie sessão novamente.';

  @override
  String get serverError => 'Erro do servidor';

  @override
  String get profileUpdateFailed => 'Falha ao atualizar perfil';

  @override
  String get healthTab => 'Saúde';

  @override
  String get healthSummary => 'Resumo';

  @override
  String get healthWeight => 'Peso';

  @override
  String get healthSleep => 'Sono';

  @override
  String get healthWater => 'Água';

  @override
  String get healthSteps => 'Passos';

  @override
  String get todaySummary => 'Resumo de hoje';

  @override
  String get noData => 'Sem dados';

  @override
  String get quality => 'Qualidade';

  @override
  String get goal => 'Objetivo';

  @override
  String get todayDrunk => 'Bebido hoje';

  @override
  String get history => 'Histórico';

  @override
  String get noWaterRecords => 'Sem registos de água';

  @override
  String get glass => 'Copo';

  @override
  String get bottle => 'Garrafa';

  @override
  String get editVolume => 'Editar volume (ml)';

  @override
  String get deleteRecord => 'Apagar registo';

  @override
  String get deleteRecordConfirm => 'Esta ação não pode ser desfeita.';

  @override
  String get editEntry => 'Editar entrada';

  @override
  String get weeklyStats => 'Estatísticas semanais';

  @override
  String get editSteps => 'Editar passos';

  @override
  String get stepsHistory => 'Histórico de passos';

  @override
  String get noSleepRecords => 'Sem registos de sono';

  @override
  String get noWeightRecords => 'Sem registos de peso';

  @override
  String get addWeight => 'Adicionar peso';

  @override
  String get addSleep => 'Adicionar sono';

  @override
  String get bedtime => 'Hora de dormir';

  @override
  String get wakeTime => 'Hora de acordar';

  @override
  String get totalSleep => 'Sono total';

  @override
  String get sleepQuality => 'Qualidade do sono';

  @override
  String get feedMyFeed => 'A minha feed';

  @override
  String get feedSubscriptions => 'Subscrições';

  @override
  String get feedEmptyMy => 'Ainda não há atividades na nuvem';

  @override
  String get feedEmptyFriends => 'Feed de amigos vazia';

  @override
  String get activityMoving => 'Tempo em movimento';

  @override
  String get activityMaxSpeed => 'Velocidade máx.';

  @override
  String get activityAvgSpeed => 'Velocidade média';

  @override
  String get activityElevation => 'Ganho de elevação';

  @override
  String get activityNoNotes => 'Sem notas';

  @override
  String get activityAddPhoto => 'Adicionar foto';

  @override
  String get activityDeleteTitle => 'Apagar atividade?';

  @override
  String get activityDeleteMsg => 'Esta ação não pode ser desfeita.';

  @override
  String get activityTryAgain => 'Tentar novamente';

  @override
  String get activityDisplayError => 'Erro de exibição';

  @override
  String get activityCouldNotDisplay => 'Não foi possível exibir a atividade:';

  @override
  String get activityCharts => 'Gráficos';

  @override
  String get activitySpeed => 'Velocidade';

  @override
  String get activityAltitude => 'Altitude';

  @override
  String get activitySplit => 'Split';

  @override
  String get activitySplitPace => 'Ritmo';

  @override
  String get activitySplitElev => 'Elevação';

  @override
  String get activityPR => 'Recorde pessoal';

  @override
  String get activityPRBadge => 'Novo recorde!';

  @override
  String get gearNotFound => 'Equipamento não encontrado';

  @override
  String get gearPrimary => 'PRIMÁRIO';

  @override
  String get gearMakePrimary => 'Definir como primário para:';

  @override
  String get gearDefaultCats =>
      'Sem categorias predefinidas para este tipo de equipamento';

  @override
  String get gearClose => 'Fechar';

  @override
  String get gearTotalKm => 'Distância total';

  @override
  String get gearPurchaseCost => 'Custo de aquisição';

  @override
  String get gearPartsCost => 'Custo de peças';

  @override
  String get notifSyncComplete => 'Sincronização concluída';

  @override
  String get notifSync => 'Sincronizar';

  @override
  String get notifSyncStatus => 'Estado da sincronização';

  @override
  String get settingsStatsDisplay => 'Exibição de estatísticas';

  @override
  String get settingsStatsRings => 'Indicadores anulares';

  @override
  String get settingsStatsCards => 'Grelha de cartões';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginOr => 'ou';

  @override
  String get loginWithSSO => 'Entrar com SSO';

  @override
  String get trackingDistance => 'Distância';

  @override
  String get trackingDuration => 'Duração';

  @override
  String get trackingCurrentSpeed => 'Velocidade';

  @override
  String get trackingElevationGain => 'Ganho de elevação';

  @override
  String get healthHeartRate => 'Freq. Cardíaca';

  @override
  String get importFromHealthConnect => 'Importar do Health Connect';

  @override
  String importSummary(Object count) {
    return 'Importado: $count registos';
  }

  @override
  String get hrZoneRest => 'Repouso';

  @override
  String get hrZoneFatBurn => 'Queima de Gordura';

  @override
  String get hrZoneCardio => 'Cardio';

  @override
  String get hrZonePeak => 'Pico';

  @override
  String get importing => 'A importar...';

  @override
  String get noHeartRateRecords => 'Sem registos de freq. cardíaca';

  @override
  String get healthConnectNotAvailable =>
      'Health Connect não está disponível neste dispositivo';
}
