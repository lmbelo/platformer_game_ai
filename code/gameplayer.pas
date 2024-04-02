unit GamePlayer;

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  CastleTransform,
  CastleVectors,
  CastleSceneCore,
  CastleScene,
  X3DNodes;

type
  TPlayer = class(TCastleBehavior)
  private
    FScene: TCastleScene;
    FRBody: TCastleRigidBody;
    { Player abilities }
    FPlayerHitPoints: byte;
    FWasInputJump: boolean;
    FPlayerAnimationToLoop: String;

    procedure ConfigurePlayerPhysics(const Player:TCastleScene);
    procedure ConfigurePlayerAbilities(const Player:TCastleScene);

    procedure PlayerCollisionEnter(const CollisionDetails: TPhysicsCollisionDetails);
    procedure PlayerCollisionExit(const CollisionDetails: TPhysicsCollisionDetails);

    procedure PlayAnimationOnceAndLoop(Scene: TCastleScene;
      const AnimationNameToPlayOnce, AnimationNameToLoop: String);
    procedure OnAnimationStop(const Scene: TCastleSceneCore;
      const Animation: TTimeSensorNode);

    { Life support }
    procedure ResetHitPoints;
    procedure SetHitPoints(const HitPoints: Integer);

    { More advanced version with physics ray to check "Are we on ground?",
      double jump, shot and move acceleration frame rate independed }
    procedure UpdatePlayerByVelocityAndPhysicsRayWithDblJumpShot(
      const SecondsPassed: Single);
  protected
    { Check pressed keys and mouse/touch, to support both keyboard
      and mouse and touch (on mobile) navigation. }
    function InputLeft: Boolean; virtual;
    function InputRight: Boolean; virtual;
    function InputJump: Boolean; virtual;

    function EnemyBehind(): single;
    function DeadlyObstacleAhead(): single;
  public
    procedure ParentAfterAttach; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;

    procedure Setup(const AIndex: integer); virtual;

    procedure HitPlayer;
    function IsPlayerDead: Boolean;
  end;

  TPlayerList = TObjectList<TPlayer>;

implementation

uses
  System.Math,
  CastleComponentSerialize,
  CastleControls,
  CastleUIControls,
  CastleKeysMouse,
  CastleSoundEngine,
  GameSound,
  GameViewPlay,
  CastleLog;

procedure TPlayer.ParentAfterAttach;
begin
  inherited;
  FScene := Parent as TCastleScene;
  FRBody := FScene.FindBehavior(TCastleRigidBody) as TCastleRigidBody;
end;

procedure TPlayer.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  inherited;
  UpdatePlayerByVelocityAndPhysicsRayWithDblJumpShot(SecondsPassed);
end;

procedure TPlayer.ConfigurePlayerPhysics(const Player: TCastleScene);
var
  LRBody: TCastleRigidBody;
begin
  LRBody := Player.FindBehavior(TCastleRigidBody) as TCastleRigidBody;
  if LRBody<> nil then begin
    LRBody.OnCollisionEnter := PlayerCollisionEnter;
    LRBody.OnCollisionExit := PlayerCollisionExit;
  end;

  FWasInputJump := false;
end;

procedure TPlayer.ConfigurePlayerAbilities(const Player: TCastleScene);
begin
  ResetHitPoints;
end;

procedure TPlayer.PlayerCollisionEnter(
  const CollisionDetails: TPhysicsCollisionDetails);
begin
  if CollisionDetails.OtherTransform <> nil then
  begin
    if Pos('GoldCoin', CollisionDetails.OtherTransform.Name) > 0 then
    begin
      CollisionDetails.OtherTransform.Exists := false;
    end else
    if Pos('DblJump', CollisionDetails.OtherTransform.Name) > 0 then
    begin
      //SoundEngine.Play(NamedSound('PowerUp'));
      //FPlayerCanDoubleJump := true;
      CollisionDetails.OtherTransform.Exists := false;
    end else
    if Pos('Shot', CollisionDetails.OtherTransform.Name) > 0 then
    begin
      //SoundEngine.Play(NamedSound('PowerUp'));
      CollisionDetails.OtherTransform.Exists := false;
    end else
    if Pos('Key', CollisionDetails.OtherTransform.Name) > 0 then
    begin
      CollisionDetails.OtherTransform.Exists := false;
    end else
    if Pos('Door', CollisionDetails.OtherTransform.Name) > 0 then
    begin
      //if PlayerHasKey then
      //  LevelComplete := true
      //else
        { Show no key message. }
      //  CollisionDetails.OtherTransform.Items[0].Exists := true;
    end;
  end;
end;

procedure TPlayer.PlayerCollisionExit(
  const CollisionDetails: TPhysicsCollisionDetails);
begin
  //if CollisionDetails.OtherTransform <> nil then
  //begin
  //  if (Pos('Door', CollisionDetails.OtherTransform.Name) > 0) and
  //     (not PlayerHasKey) then
  //    CollisionDetails.OtherTransform.Items[0].Exists := false;
  //end;
end;

procedure TPlayer.PlayAnimationOnceAndLoop(Scene: TCastleScene;
  const AnimationNameToPlayOnce, AnimationNameToLoop: String);
var
  Parameters: TPlayAnimationParameters;
begin
  Parameters := TPlayAnimationParameters.Create;
  try
    Parameters.Loop := false;
    Parameters.Name := AnimationNameToPlayOnce;
    Parameters.Forward := true;
    Parameters.StopNotification := OnAnimationStop;
    FPlayerAnimationToLoop := AnimationNameToLoop;
    Scene.PlayAnimation(Parameters);
  finally
    FreeAndNil(Parameters);
  end;
end;

procedure TPlayer.OnAnimationStop(const Scene: TCastleSceneCore;
  const Animation: TTimeSensorNode);
begin
  Scene.PlayAnimation(FPlayerAnimationToLoop, true);
end;

procedure TPlayer.ResetHitPoints;
begin
  SetHitPoints(1);
end;

procedure TPlayer.SetHitPoints(const HitPoints: Integer);
begin
  FPlayerHitPoints := HitPoints;
end;

procedure TPlayer.Setup(const AIndex: integer);
begin
  ConfigurePlayerPhysics(FScene);
  ConfigurePlayerAbilities(FScene);
  FScene.Exists := true;
end;

function TPlayer.InputLeft: Boolean;
//var
//  I: Integer;
begin
//  Result :=
//    ViewPlay.Container.Pressed.Items[keyA] or
//    ViewPlay.Container.Pressed.Items[keyArrowLeft];
//
//  { Mouse, or any finger, pressing in left-lower part of the screen.
//
//    Note: if we would not need to support multi-touch (and only wanted
//    to check 1st finger) then we would use simpler "Container.MousePosition"
//    instead of "Container.TouchesCount", "Container.Touches[..].Position". }
//
//  if buttonLeft in ViewPlay.Container.MousePressed then
//    for I := 0 to ViewPlay.Container.TouchesCount - 1 do
//      if (ViewPlay.Container.Touches[I].Position.X < ViewPlay.Container.PixelsWidth * 0.5) and
//         (ViewPlay.Container.Touches[I].Position.Y < ViewPlay.Container.PixelsHeight * 0.5) then
//        Exit(true);

  Exit(False); // Forbbiden movement
end;

function TPlayer.InputRight: Boolean;
var
  I: Integer;
begin
  Result :=
    ViewPlay.Container.Pressed.Items[keyD] or
    ViewPlay.Container.Pressed.Items[keyArrowRight];

  { Mouse, or any finger, pressing in left-lower part of the screen. }
  if buttonLeft in ViewPlay.Container.MousePressed then
    for I := 0 to ViewPlay.Container.TouchesCount - 1 do
      if (ViewPlay.Container.Touches[I].Position.X >= ViewPlay.Container.PixelsWidth * 0.5) and
         (ViewPlay.Container.Touches[I].Position.Y < ViewPlay.Container.PixelsHeight * 0.5) then
        Exit(true);
end;

function TPlayer.InputJump: Boolean;
var
  I: Integer;
begin
  Result :=
    ViewPlay.Container.Pressed.Items[keyW] or
    ViewPlay.Container.Pressed.Items[keyArrowUp];

  { Mouse, or any finger, pressing in upper part of the screen. }
  if buttonLeft in ViewPlay.Container.MousePressed then
    for I := 0 to ViewPlay.Container.TouchesCount - 1 do
      if (ViewPlay.Container.Touches[I].Position.Y >= ViewPlay.Container.PixelsHeight * 0.5) then
        Exit(true);
end;

procedure TPlayer.HitPlayer;
begin
  SetHitPoints(FPlayerHitPoints - 1);
  SoundEngine.Play(NamedSound('Hurt'));
  PlayAnimationOnceAndLoop(FScene, 'hurt', 'idle');
  FScene.Exists := false;
end;

function TPlayer.IsPlayerDead: Boolean;
begin
  Result := FPlayerHitPoints <= 0;
end;

function TPlayer.EnemyBehind: single;
begin
  Result := -9999;

  if not FScene.Exists then
    Exit;

  var LRayMaxDistance := FScene.BoundingBox.SizeX * 0.5 + 200;
  var LEnemyBehindRayCast := FRBody.PhysicsRayCast(
    Vector3(FScene.Translation.X - (FScene.BoundingBox.SizeX / 2), - 652, FScene.Translation.Z),
    Vector3(-1, 0, 0),
    LRayMaxDistance);

  var LSpider: TCastleTransform := nil;
  if Assigned(LEnemyBehindRayCast.Transform) and (Pos('Spider', LEnemyBehindRayCast.Transform.Name) <> 0) then
    LSpider := LEnemyBehindRayCast.Transform;

  if Assigned(LSpider) then
    WritelnLog('Enemy behind: ' + Trunc(LEnemyBehindRayCast.Distance).ToString());

  if Assigned(LSpider) then
    Result := LEnemyBehindRayCast.Distance;
end;

function TPlayer.DeadlyObstacleAhead: single;
begin
  Result := -9999;

  if not FScene.Exists then
    Exit;

  var LRayMaxDistance := FScene.BoundingBox.SizeX + 200;
  var LLDeadlyObstacleAheadRayCast := FRBody.PhysicsRayCast(
    Vector3(FScene.Translation.X + (FScene.BoundingBox.SizeX / 2) - 10, -683, FScene.Translation.Z),
    Vector3(1, 0, 0),
    LRayMaxDistance);

  var LDeadlyObstacle: TCastleTransform := nil;
  if Assigned(LLDeadlyObstacleAheadRayCast.Transform) and (Pos('DeadlyObstacle', LLDeadlyObstacleAheadRayCast.Transform.Name) <> 0) then
    LDeadlyObstacle := LLDeadlyObstacleAheadRayCast.Transform;

  if Assigned(LDeadlyObstacle) then
    WritelnLog('Deadly obstacle ahead: ' + Trunc(LLDeadlyObstacleAheadRayCast.Distance).ToString());

  if Assigned(LDeadlyObstacle) then
    Result := LLDeadlyObstacleAheadRayCast.Distance;
end;

procedure TPlayer.UpdatePlayerByVelocityAndPhysicsRayWithDblJumpShot(
  const SecondsPassed: Single);
const
  JumpVelocity = 460;
  MaxHorizontalVelocity = 345;
  { We need multiply any horizontal velocity speed by SecondsPassed.
    Without that when game will run 120 FPS, player will accelerated
    twice faster than on 60 FPS.
    So MaxHorizontalVelocityChange is designed and tested on 60 FPS so we need
    multiply MaxHorizontalVelocity by 60 to get it.

    It's easy to realize when you know that for 60 FPS:

    MaxHorizontalVelocityChange * SecondsPassed * 60 = 350
    21000 * (1/60) * 60 = 350
    21000 * 0.01666 * 60 = 350

    And for 120 FPS:
    21000 * (1/120) * 60 = 175
    21000 * 0.008333 * 60 = 175
    For 120 FPS every frame max speed up will be 175 but you have two times
    more frames (updates). So 175 * 2 = 350 like in 60 FPS.

    We don't need that for jump because jump is one time event not changed
    per update. If something depend from update call frequency you need make it
    depend from time passed in CGE SecondsPassed.
    }
  MaxHorizontalVelocityChange = MaxHorizontalVelocity * 60;
var
  DeltaVelocity: TVector3;
  Vel: TVector3;
  PlayerOnGround: Boolean;
  GroundScene: TCastleTransform;
  EnemyScene: TCastleTransform;
begin
  { This method is executed every frame.}

  { When player is dead, he can't do anything }
  if IsPlayerDead then
    Exit;

  if FRBody = nil then
    Exit;

  DeltaVelocity := Vector3(0, 0, 0);
  Vel := FRBody.LinearVelocity;

  { Check player is on ground }
  GroundScene := FRBody.PhysicsRayCast(FScene.Translation,
    Vector3(0, -1, 0), FScene.BoundingBox.SizeY / 2 + 5).Transform;

  if Assigned(GroundScene) then
    if Pos('Ground', GroundScene.Name) = 0 then
      GroundScene := nil;

  { Two more checks - player should slide down when player just
    on the edge, but sometimes it stay and center ray don't "see" that we are
    on ground }
  if GroundScene = nil then
  begin
    GroundScene := FRBody.PhysicsRayCast(FScene.Translation
      + Vector3(-FScene.BoundingBox.SizeX * 0.30, 0, 0),
      Vector3(0, -1, 0), FScene.BoundingBox.SizeY / 2 + 5).Transform;
  end;

  if Assigned(GroundScene) then
    if Pos('Ground', GroundScene.Name) = 0 then
      GroundScene := nil;

  if GroundScene = nil then
  begin
    GroundScene := FRBody.PhysicsRayCast(FScene.Translation
      + Vector3(FScene.BoundingBox.SizeX * 0.30, 0, 0),
      Vector3(0, -1, 0), FScene.BoundingBox.SizeY / 2 + 5).Transform;
  end;

  if Assigned(GroundScene) then
    if Pos('Ground', GroundScene.Name) = 0 then
      GroundScene := nil;

  { Player is on ground when RayCasts hits something }
  PlayerOnGround := (GroundScene <> nil);

  { Can jump over enemies. }
  if not PlayerOnGround then begin
    EnemyScene := FRBody.PhysicsRayCast(FScene.Translation,
      Vector3(0, -1, 0), FScene.BoundingBox.SizeY * 2 + 5).Transform;

    // Jumping over a spider
    if Assigned(EnemyScene) and (Pos('Spider', EnemyScene.Name) <> 0) then begin
      HitPlayer();
    end;
  end;

  { Flag for velocity calculation when second jump starts in this Update }
  if InputJump then
  begin
    { Player can jump when:
      - is on ground
      - he can double jump and there was not WasDoubleJump
      - here we also check if the key has just been pressed (when it is held,
        the player should not keep jumping) }
    if (not FWasInputJump) and PlayerOnGround then
    begin
      SoundEngine.Play(NamedSound('Jump'));
      DeltaVelocity.Y := JumpVelocity;
      FWasInputJump := true;
    end;
  end else
    FWasInputJump := false;

  if InputRight then
  begin
    if PlayerOnGround then
      DeltaVelocity.x := MaxHorizontalVelocityChange * SecondsPassed / 2
    else 
      { This add a little control when you in the air during jumping or falling }
      DeltaVelocity.x := MaxHorizontalVelocityChange * SecondsPassed / 14;
  end;

  if InputLeft then
  begin
    if PlayerOnGround then
      DeltaVelocity.x := - MaxHorizontalVelocityChange * SecondsPassed / 2
    else 
      { This add a little control when you in the air during jumping or falling }
      DeltaVelocity.x := - MaxHorizontalVelocityChange * SecondsPassed / 14;
  end;

  if Vel.X + DeltaVelocity.X > 0 then
    Vel.X := Min(Vel.X + DeltaVelocity.X, MaxHorizontalVelocity)
  else
    Vel.X := Max(Vel.X + DeltaVelocity.X, -MaxHorizontalVelocity);

  Vel.Y := Vel.Y + DeltaVelocity.Y;
  Vel.Z := 0;

  { Stop the player without slipping }
  if PlayerOnGround and (not InputRight) and (not InputLeft) then
    Vel.X := 0;

  { Player can't move when hurt on ground }
  if PlayerOnGround and (FScene.CurrentAnimation.X3DName = 'hurt') then
  begin
    Vel.X := 0;
    Vel.Y := 0;
  end;

  FRBody.LinearVelocity := Vel;

  { Set animation }

  { Don't change animation when player are hurt }
  if FScene.CurrentAnimation.X3DName <> 'hurt' then
  begin
    { We get here 20 because vertical velocity calculated by physics engine when
      player is on platform have no 0 but some small values to up and down sometimes
      It can fail when the player goes uphill (will set jump animation) or down
      will set fall animation }
    if (not PlayerOnGround) and (Vel.Y > 20) then
      FScene.PlayAnimation('jump', true)
    else
    if (not PlayerOnGround) and (Vel.Y < -20) then
      FScene.PlayAnimation('fall', true)
    else
      if Abs(Vel.X) > 1 then
      begin
        if FScene.CurrentAnimation.X3DName <> 'walk' then
          FScene.PlayAnimation('walk', true);
      end
      else
        FScene.PlayAnimation('idle', true);
  end;

  { Here we use horizontal velocity to change player scene direction to moving
    direction. }
  if Vel.X < -1 then
    FScene.Scale := Vector3(-1, 1, 1)
  else if Vel.X > 1 then
    FScene.Scale := Vector3(1, 1, 1);
end;

initialization
  { Optional: If you want to make this behavior available in the editor,
    add GamePlayer to the editor_units="..." in CastleEngineManifest.xml
    and reopen the project.
    It will build a custom editor with this behavior available at design-time.
    See https://castle-engine.io/custom_components .

    Note that you don't *need* to do this.
    Even without any change to CastleEngineManifest.xml,
    you can use the new behavior class in code,
    e.g. create it in the view TMyView.Start method:

      MyPlayer := TPlayer.Create(FreeAtStop);
      MyTransform.AddBehavior(MyPlayer);
  }
  RegisterSerializableComponent(TPlayer, 'Player');
end.
