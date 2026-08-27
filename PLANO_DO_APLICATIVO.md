# PLANO_DO_APLICATIVO.md

> Documento de planejamento de arquitetura. **Nenhum código funcional foi implementado.**
> Este arquivo deve ser atualizado ANTES de qualquer mudança estrutural futura.

## 0. Visão Geral

Aplicativo de comunicação em tempo real (texto + voz), organizado em grupos e canais,
inspirado em Discord/RaidCall, com stack **Flutter** (app) + **Firebase** (Auth + Firestore).

Princípios do plano:
- Cada responsabilidade em um arquivo próprio (nada de "God files").
- A camada de voz e o serviço de segundo plano do Android são tratados como
  infraestrutura central, não como feature de tela — por isso são projetados
  antes de qualquer UI "bonita".
- Camadas: models -> services (regras/IO) -> providers/controllers (estado) -> screens/widgets (UI).

---

## 1. Arquitetura em Camadas

UI (screens/widgets)
   -> consome
State/Controllers (providers - Riverpod recomendado)
   -> chama
Services (auth, chat, voice, presence, ranking...)
   -> acessa
Data Sources (Firestore, REST, WebRTC, Platform Channels)
   -> se comunica com
Android Foreground Service (nativo, via MethodChannel/EventChannel)

Regra fixa: screens nunca chamam Firestore/WebRTC diretamente — sempre via service.

---

## 2. Árvore Completa de Arquivos

lib/
  main.dart
  app.dart
  bootstrap/
    app_bootstrap.dart
    env_config.dart
  core/
    constants/
      app_constants.dart
      permission_constants.dart
      ranking_constants.dart
    errors/
      app_exception.dart
      error_handler.dart
    network/
      connectivity_service.dart
      realtime_client.dart
    platform/
      voice_platform_channel.dart
      notification_platform_channel.dart
    utils/
      validators.dart
      date_utils.dart
      logger.dart
  models/
    user_model.dart
    user_settings_model.dart
    group_model.dart
    member_model.dart
    role_model.dart
    permission_model.dart
    channel_model.dart
    message_model.dart
    attachment_model.dart
    voice_room_state_model.dart
    voice_participant_model.dart
    presence_model.dart
    notification_model.dart
    invite_model.dart
    ranking_model.dart
  services/
    auth/
      auth_service.dart
      auth_repository.dart
      session_manager.dart
    profile/
      profile_service.dart
      avatar_upload_service.dart
    groups/
      group_service.dart
      membership_service.dart
      invite_service.dart
    channels/
      channel_service.dart
      channel_permission_service.dart
    chat/
      message_service.dart
      message_pagination_service.dart
      attachment_service.dart
    voice/
      voice_room_service.dart
      webrtc_client.dart
      voice_signaling_service.dart
      voice_reconnection_service.dart
      voice_permission_service.dart
    presence/
      presence_service.dart
    notifications/
      push_notification_service.dart
      notification_router.dart
    ranking/
      ranking_service.dart
      ranking_rules.dart
    permissions/
      permission_resolver.dart
    settings/
      settings_service.dart
  providers/
    auth_provider.dart
    profile_provider.dart
    group_provider.dart
    channel_provider.dart
    chat_provider.dart
    voice_room_provider.dart
    presence_provider.dart
    notification_provider.dart
    ranking_provider.dart
    settings_provider.dart
  screens/
    auth/
      login_screen.dart
      register_screen.dart
      password_recovery_screen.dart
    home/
      home_screen.dart
    group/
      group_list_screen.dart
      group_detail_screen.dart
      group_create_screen.dart
      group_settings_screen.dart
      group_members_screen.dart
    channel/
      text_channel_screen.dart
      channel_settings_screen.dart
    voice/
      voice_room_screen.dart
      voice_room_minimized_widget.dart
    profile/
      profile_screen.dart
      edit_profile_screen.dart
    settings/
      settings_screen.dart
      audio_settings_screen.dart
      notification_settings_screen.dart
      privacy_settings_screen.dart
    ranking/
      ranking_screen.dart
  widgets/
    common/
      app_avatar.dart
      loading_indicator.dart
      confirm_dialog.dart
    chat/
      message_bubble.dart
      message_input_bar.dart
      attachment_preview.dart
    voice/
      participant_tile.dart
      mic_control_button.dart
      connection_status_badge.dart

android/
  app/src/main/kotlin/.../
    MainActivity.kt
    voice/
      VoiceForegroundService.kt
      VoiceServiceConnection.kt
      VoiceNotificationBuilder.kt
    channels/
      VoiceMethodChannelHandler.kt
      NotificationMethodChannelHandler.kt

Total aproximado: 85-95 arquivos na primeira versão completa (sem contar testes).

---

## 3. Banco de Dados (coleções Firestore)

- users: id, username, avatarUrl, status, createdAt (perfil público)
- user_settings: userId, audioPrefs, notifPrefs, privacyPrefs (privado)
- groups: id, name, ownerId, iconUrl, createdAt
- memberships: groupId, userId, roleId, joinedAt (índice composto groupId+userId)
- roles: id, groupId, name, permissionsBitmask (Owner/Admin/Mod/Member + custom)
- channels: id, groupId, type(text/voice), order, permissionOverrides
- messages: id, channelId, authorId, content, attachments[], replyToId, editedAt, deletedAt
- invites: code, groupId, createdBy, expiresAt, maxUses, uses
- voice_rooms (realtime): channelId, participants[], speakingUserIds[] (efêmero)
- voice_signaling (realtime): roomId, sdp/ice por par de usuários (efêmero, TTL curto)
- presence (realtime): userId, state(online/offline/inRoom/away), lastSeen
- notifications: id, userId, type, payload, read, createdAt
- ranking: userId, points, level, voiceMinutes, updatedAt

---

## 4. Realtime — o que precisa ser tempo real

- Mensagens de texto: stream por canal.
- Sinalização de voz (entrada/saída, SDP/ICE, quem fala): stream por sala.
- Presença: stream global do usuário + por grupo.
- Notificações: push (FCM) + stream in-app para badge/menções.
- Ranking: atualização otimista local + sync periódico é suficiente (não precisa realtime "duro").

---

## 5. Segurança

- Autenticação obrigatória em toda operação de escrita (Firestore Security Rules).
- Autorização sempre resolvida no backend, nunca confiar só no Flutter (permission_resolver.dart é espelho local, não fonte da verdade).
- Validação de payload (tamanho de mensagem, tipos de anexo, rate limit de envio).
- Prevenção contra escalonamento de permissão: só o dono altera cargos de admin; admin não se autopromove.
- Sinalização de voz e tokens de mídia com TTL curto e escopo por sala.
- Sanitização de conteúdo de mensagens.

---

## 6. Android em Segundo Plano (núcleo técnico da sala de voz)

Fluxo:
1. Usuário entra na sala -> voice_room_service.dart inicia conexão WebRTC.
2. Flutter chama (via voice_platform_channel.dart) o Android para iniciar o VoiceForegroundService (tipo microphone/mediaPlayback).
3. VoiceForegroundService.kt sobe notificação persistente (VoiceNotificationBuilder.kt) com ações rápidas (sair, mutar).
4. Áudio fica vinculado ao Foreground Service, não à Activity — sobrevive a minimizar, trocar de app e bloquear tela.
5. Ao voltar ao app, a UI Flutter apenas re-observa o estado que o serviço já mantém (via EventChannel).
6. Se a internet cair: voice_reconnection_service.dart detecta via connectivity_service.dart e tenta reconexão com backoff, mantendo o serviço vivo.
7. Ao sair da sala: serviço encerra, notificação some.

Pontos de atenção: permissão de notificação (Android 13+), tipos de foreground service no manifest, restrições de fabricantes (battery optimization).

---

## 7. Cargos e Permissões

Cada role tem bitmask de permissões (MANAGE_CHANNELS, MANAGE_ROLES, KICK_MEMBERS, MUTE_MEMBERS, SPEAK_IN_VOICE, SEND_MESSAGES...). Canais podem ter overrides por cargo. Prioridade: override de canal > cargo > default do grupo.

---

## 8. Ranking e Níveis (do zero)

- Pontos por: tempo em sala de voz (com teto diário antiabuso), mensagens enviadas (limite antispam), participação em eventos.
- Nível = função sobre pontos acumulados (curva de progressão suave).
- Antiabuso: pontos de voz só contam com mais de 1 participante falando; cooldown entre mensagens pontuáveis.

---

## 9. Principais Dependências (pubspec)

- flutter_riverpod: gerenciamento de estado
- firebase_auth: autenticação
- cloud_firestore: dados e realtime de texto/presença
- flutter_webrtc: áudio em tempo real
- serviço nativo próprio (VoiceForegroundService.kt): persistência em segundo plano
- permission_handler: permissões de mic/notificação
- flutter_local_notifications: notificação persistente
- firebase_messaging: push notifications
- connectivity_plus: detecção de rede
- image_picker + firebase_storage: avatar e anexos
- freezed / json_serializable: models imutáveis

Observação: para voz com muitos participantes por sala, considerar SFU gerenciado (ex. LiveKit) em vez de WebRTC P2P puro — decidir antes de implementar a sala de voz.

---

## 10. Fluxos Principais

Fluxo geral: Cadastro -> Login -> Home -> Grupo -> Canal -> Sala de voz -> Minimizar -> Segundo plano -> Tela bloqueada -> Retornar ao app -> Sair da sala.

Fluxo de voz: Entra na sala -> mic ativo -> fala -> outros recebem áudio -> minimiza -> Foreground Service mantém tudo -> volta ao app -> UI resincroniza.

Fluxo de reconexão: Perde conexão -> detecta -> tenta reconectar com backoff -> restaura estado da sala.

---

## 11. Ordem de Implementação

1. Fundação: core/, models/, autenticação, sessão persistente.
2. Grupos e canais (CRUD básico) + cargos/permissões básicas.
3. Chat de texto em tempo real.
4. Prova de conceito de voz + segundo plano isoladamente (decidir SFU, VoiceForegroundService funcionando, testar minimizar/bloquear tela) — maior risco do projeto, validar antes de investir em UI.
5. Integração completa da sala de voz (participantes, mute, indicador de fala, reconexão).
6. Presença.
7. Notificações.
8. Ranking e níveis.
9. Configurações completas.
10. Polimento de UI/UX por último.

---

## 12. Testes por Funcionalidade

- Entrar/falar/ouvir na sala: manual com 2+ dispositivos + testes unitários com mocks do WebRTC client.
- Vários usuários simultâneos: manual com 3+ participantes reais.
- Minimizar/trocar de app/bloquear tela: teste manual guiado.
- Perder/recuperar internet: modo avião durante chamada.
- Sair da sala: verificar que o serviço encerra e notificação some.
- Android matando processo: testar em fabricantes agressivos (Xiaomi/Samsung).
- Permissões de microfone: testar negar e pedir novamente.
- Notificações: testar Android 13+.
- Auth: testes unitários + integração de UI.
- Mensagens: testes unitários + scroll infinito manual.
- Permissões por cargo/canal: testes unitários do permission_resolver.
- Ranking: testes unitários das regras de pontuação isoladas de IO.

---

## 13. Riscos Técnicos Principais

1. Voz em segundo plano no Android — risco #1. Mitigar validando cedo (etapa 4).
2. Escolha de arquitetura de voz (P2P vs SFU) — recomendado SFU gerenciado.
3. Consistência de permissões entre backend (fonte da verdade) e cliente.
4. Custo/limites do Firestore com uso intenso de chat + presença.
5. Antiabuso do ranking (farm de pontos em sala de voz).

---

## 14. Regras para Desenvolvimento Futuro

- Não alterar arquitetura sem atualizar este documento primeiro.
- Antes de criar funcionalidade nova, consultar este arquivo.
- Mudança estrutural -> atualizar o plano -> só então implementar.
- Sem soluções temporárias que exigirão reescrita completa.
- Sem duplicação de services/models/lógica.
- Cada responsabilidade no seu arquivo — nada de lógica de negócio em screens/.