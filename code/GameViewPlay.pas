{
  Copyright 2021-2021 Andrzej Kilijański, Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Main "playing game" view, where most of the game logic takes place. }
unit GameViewPlay;

interface

uses Classes,
  CastleComponentSerialize, CastleUIControls, CastleControls,
  CastleKeysMouse, CastleViewport, CastleScene, CastleSceneCore, CastleVectors,
  CastleTransform, CastleSoundEngine, X3DNodes,
  GameEnemy, GameDeadlyObstacle, GamePlayer, GamePlayerBrained;

type
  TLevelBounds = class (TComponent)
  public
    Left: Single;
    Right: Single;
    Top: Single;
    Down: Single;
    constructor Create(AOwner: TComponent);override;
  end;

  { Main "playing game" view, where most of the game logic takes place. }
  TViewPlay = class(TCastleView)
  private
    FTraining: boolean;
    FRecreatePlayers: boolean;
    FRestarting: boolean;
  published
    { Components designed using CGE editor.
      These fields will be automatically initialized at Start. }
    LabelFps: TCastleLabel;
    LabelEnemyBehind: TCastleLabel;
    LabelDeadlyObstacleAhead: TCastleLabel;
    LabelRun: TCastleLabel;
    LabelJump: TCastleLabel;
    MainViewport: TCastleViewport;
    ScenePlayer: TCastleScene;
    SceneSpider: TCastleScene;
  strict private const
    POPULATION_COUNT = 90;
  strict private
    { Level bounds }
    LevelBounds: TLevelBounds;
    { Deadly obstacles (spikes) behaviors }
    DeadlyObstacles: TDeadlyObstaclesList;

    procedure CreatePlayers();
    procedure CreateEnemies();

    procedure RestartPlayers();
    procedure RestartEnemies();

    procedure DestroyPlayers();
    procedure DestroyEnemies();

    function PlayersAlive: byte;
    function FurtherPlayer(): TCastleScene;

    procedure BeginOfTurn();
    procedure EndOfTurn();

    procedure OnLog(const AMessage: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure Start; override;
    procedure Stop; override;
    procedure Resume; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;

    procedure PauseGame;
    procedure ResumeGame;

    property Training: boolean read FTraining write FTraining;
    property RecreatePlayers: boolean read FRecreatePlayers write FRecreatePlayers;
  end;

var
  ViewPlay: TViewPlay;

implementation

uses
  SysUtils, Math,
  CastleApplicationProperties,
  CastleLog,
  GameSound, GameViewMenu, GameViewGameOver, GameViewLevelComplete, GameViewPause,
  GameNeuralNetwork;

{ TLevelBounds --------------------------------------------------------------- }

constructor TLevelBounds.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Left := -3072;
  Right := 5120;
  Top := 3072;
  Down := -800;
end;

{ TViewPlay ----------------------------------------------------------------- }

constructor TViewPlay.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gameviewplay.castle-user-interface';
  ApplicationProperties.OnLog.Add(OnLog);
  FTraining := true;
  FRecreatePlayers := false;
end;

procedure TViewPlay.CreateEnemies;
const
  ENEMY_COUNT = 1;
begin
  var LEnemiesRoot := DesignedComponent('Enemies') as TCastleTransform;
  for var I := 0 to ENEMY_COUNT - 1 do begin
    var LScene := TransformLoad('castle-data:/enemies/scene_spider.castle-transform', LEnemiesRoot);

    LScene.Translation := Vector3(-2900, -580.6, 0);
    LScene.Translation := Vector3(LScene.Translation.X + I * 2, LScene.Translation.Y, LScene.Translation.Z);
    LScene.Translation := Vector3(LScene.Translation.X, LScene.Translation.Y + I * 2, LScene.Translation.Z);


    var Enemy := TEnemy.Create(LScene);
    LScene.AddBehavior(Enemy);
    LEnemiesRoot.Add(LScene);
    //LEnemiesRoot.SortBackToFront2D;
    //MainViewPort.Items.Add(LScene);
  end;
end;

procedure TViewPlay.CreatePlayers;
begin
  var LPlayersRoot := DesignedComponent('Players') as TCastleTransform;
  for var I := 0 to POPULATION_COUNT - 1 do begin
    var LScene := TransformLoad('castle-data:/player/scene_player.castle-transform', LPlayersRoot);

    LScene.Translation := Vector3(-2588.59, -600.73, 10);
    LScene.Translation := Vector3(LScene.Translation.X + Min(I, 80), LScene.Translation.Y, LScene.Translation.Z);
    LScene.Translation := Vector3(LScene.Translation.X, LScene.Translation.Y + Min(I, 80), LScene.Translation.Z);

    var LPlayer: TPlayer;
    if FTraining then
      LPlayer := TPlayerBrained.Create(LScene)
    else
      LPlayer := TPlayer.Create(LScene);

    LScene.AddBehavior(LPlayer);

    LPlayer.Setup(I);

    LPlayersRoot.Add(LScene);
    //LPlayersRoot.SortBackToFront2D;
    //MainViewPort.Items.Add(LScene);
  end;
end;

procedure TViewPlay.RestartPlayers;
begin
  var LPlayersRoot := DesignedComponent('Players') as TCastleTransform;
  for var I := 0 to LPlayersRoot.Count - 1 do begin
    var LScene := LPlayersRoot[I];

    LScene.Exists := true;

    LScene.Translation := Vector3(-2588.59, -600.73, 10);
    LScene.Translation := Vector3(LScene.Translation.X + Min(I + 2, 80), LScene.Translation.Y, LScene.Translation.Z);
    LScene.Translation := Vector3(LScene.Translation.X, LScene.Translation.Y + Min(I * 2, 100), LScene.Translation.Z);

    var LPlayer := LScene.FindBehavior(TPlayerBrained) as TPlayerBrained;
    if Assigned(LPlayer) then
      try
        LPlayer.Setup(I);
      except
        on E: Exception do
          raise Exception.Create('Player setup error: ' + E.Message);
      end;
  end;
end;

procedure TViewPlay.RestartEnemies;
begin
//  var LEnemiesRoot := DesignedComponent('Enemies') as TCastleTransform;
//  for var I := 0 to LEnemiesRoot.Count - 1 do begin
//    var LScene := LEnemiesRoot[I];
//
//    LScene.Exists := true;
//
//    LScene.Translation := Vector3(-2900, -580.6, 0);
//    LScene.Translation := Vector3(LScene.Translation.X + I * 2, LScene.Translation.Y, LScene.Translation.Z);
//    LScene.Translation := Vector3(LScene.Translation.X, LScene.Translation.Y + I * 2, LScene.Translation.Z);
//  end;
  DestroyEnemies();
  CreateEnemies();
end;

procedure TViewPlay.DestroyEnemies;
begin
  var LEnemiesRoot := DesignedComponent('Enemies') as TCastleTransform;
  for var I := LEnemiesRoot.Count - 1 downto 0 do begin
    LEnemiesRoot[I].Free();
  end;
end;

procedure TViewPlay.DestroyPlayers;
begin
  var LPlayersRoot := DesignedComponent('Players') as TCastleTransform;
  for var I := LPlayersRoot.Count - 1 downto 0 do begin
    LPlayersRoot[I].Free();
  end;
end;

destructor TViewPlay.Destroy;
begin
  ApplicationProperties.OnLog.Remove(OnLog);
  inherited;
end;

procedure TViewPlay.BeginOfTurn;
begin
  if not FTraining then
    Exit;

  FRestarting := false;;

  if FRecreatePlayers then begin
    CreateEnemies();
    CreatePlayers();
    Exit;
  end;

  RestartPlayers();
  RestartEnemies();
end;

procedure TViewPlay.EndOfTurn;
var
  LGeneticInfos: TGeneticInfosRef;
begin
  if not FTraining then begin
    // stop enemies
    var LEnemiesRoot := DesignedComponent('Enemies') as TCastleTransform;
    for var I := 0 to LEnemiesRoot.Count - 1 do begin
      var LEnemy := LEnemiesRoot[I].FindBehavior(TEnemy) as TEnemy;
      LEnemy.Teardown();
    end;

    Container.PushView(ViewGameOver);

    Exit;
  end;

  var LPlayersRoot := DesignedComponent('Players') as TCastleTransform;
  for var I := 0 to LPlayersRoot.Count - 1 do begin
    var LBrained := LPlayersRoot[I].FindBehavior(TPlayerBrained) as TPlayerBrained;
    if Assigned(LBrained) then
      LGeneticInfos := LGeneticInfos + [@LBrained.GeneticInfo];
  end;

  try
    TGeneticAlgorithm.Instance.RandomMutations(LGeneticInfos);
  except
    on E: Exception do
      raise Exception.Create('Failed on random mutations: ' + E.Message);
  end;

  //var LEnemiesRoot := DesignedComponent('Enemies') as TCastleTransform;
  //for var I := 0 to LEnemiesRoot.Count - 1 do begin
  //  var LEnemy := LEnemiesRoot[I];
  //  LEnemy.Exists := false;
  //end;

  FRestarting := true;

  if not FRecreatePlayers then
    Exit;

  DestroyEnemies();
  DestroyPlayers();
end;

procedure TViewPlay.OnLog(const AMessage: string);
begin
  if Pos('Enemy behind', AMessage) <> 0 then
    LabelEnemyBehind.Caption := AMessage
  else if Pos('Deadly obstacle ahead', AMessage) <> 0 then
    LabelDeadlyObstacleAhead.Caption := AMessage
  else if Pos('Run', AMessage) <> 0 then
    LabelRun.Caption := AMessage
  else if Pos('Jump', AMessage) <> 0 then
    LabelJump.Caption := AMessage;
end;

procedure TViewPlay.PauseGame;
begin
  MainViewport.Items.TimeScale := 0;
end;

function TViewPlay.PlayersAlive: byte;
begin
  Result := 0;
  try
    var LPlayersRoot := DesignedComponent('Players') as TCastleTransform;
    for var I := 0 to LPlayersRoot.Count - 1 do begin
      var LTransform := LPlayersRoot[I] as TCastleTransform;
        if LTransform.Exists then
          Inc(Result);
    end;
  except
    on E: Exception do
      raise Exception.Create('Failed to get players alive: ' + E.Message);
  end;
end;

function TViewPlay.FurtherPlayer: TCastleScene;
begin
  Result := nil;
  var LFurther := -9999.0;
  try
    var LPlayersRoot := DesignedComponent('Players') as TCastleTransform;
    for var I := 0 to LPlayersRoot.Count - 1 do begin
      var LTransform := LPlayersRoot[I] as TCastleTransform;
        if LTransform.Exists and (LTransform.Translation.X > LFurther) then begin
          LFurther := LTransform.Translation.X;
          Result := LTransform as TCastleScene;
        end;
    end;
  except
    on E: Exception do
      raise Exception.Create('Failed to get further player: ' + E.Message);
  end;
end;

procedure TViewPlay.ResumeGame;
begin
  MainViewport.Items.TimeScale := 1;
end;

procedure TViewPlay.Start;
var
  { TCastleTransforms that groups objects in our level }
  DeadlyObstaclesRoot: TCastleTransform;
  { Variables used when interating each object groups }
  DeadlyObstacleScene: TCastleScene;
  { Variables used to create behaviors }
  DeadlyObstacle: TDeadlyObstacle;

  I: Integer;
begin
  inherited;
  // We are not using the default (design-time) player and enemy
  DestroyEnemies();
  DestroyPlayers();

  if FTraining then
    TGeneticAlgorithm.Instance.Initialize(POPULATION_COUNT);

  {ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[0,1] := true; // ground collide with player
  ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[0,0] := true; // ground collide with ground
  ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[0,2] := true; // ground collide with enemies

  ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[1,1] := false; // player don't collide with player
  ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[1,2] := true; // player collide with enemies
  ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[1,0] := true; // player collide with ground

  ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[2,0] := true;  // enemies collide with ground
  ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[2,1] := true;  // enemies collide with player
  ScenePlayer.World.PhysicsProperties.LayerCollisons.Collides[2,2] := false; // enemies don't collide with each other

  ScenePlayer.RigidBody.Layer := 1;}

  CreateEnemies();
  CreatePlayers();

  DeadlyObstacles := TDeadlyObstaclesList.Create(true);
  DeadlyObstaclesRoot := DesignedComponent('DeadlyObstacles') as TCastleTransform;
  for I := 0 to DeadlyObstaclesRoot.Count - 1 do
  begin
    DeadlyObstacleScene := DeadlyObstaclesRoot.Items[I] as TCastleScene;
    { Below using nil as Owner of TFallingObstacle,
      as the DeadlyObstacles list already "owns" instances of this class,
      i.e. it will free them. }
    DeadlyObstacle := TDeadlyObstacle.Create(nil);
    DeadlyObstacleScene.AddBehavior(DeadlyObstacle);
    DeadlyObstacles.Add(DeadlyObstacle);
  end;

  LevelBounds := TLevelBounds.Create(DesignedComponent('Players'));

  { Play game music }
  SoundEngine.LoopingChannel[0].Sound := NamedSound('GameMusic');

  if FTraining then
    MainViewport.Items.TimeScale := 1.9; // Game speed. Set to "1" for normal speed.

  WritelnLog('Configuration done');
end;

procedure TViewPlay.Stop;
begin
  FreeAndNil(DeadlyObstacles);
  inherited;
end;

procedure TViewPlay.Resume;
begin
  inherited Resume;

  { Play game music }
  SoundEngine.LoopingChannel[0].Sound := NamedSound('GameMusic');
end;

procedure TViewPlay.Update(const SecondsPassed: Single; var HandleInput: Boolean);
var
  CamPos: TVector3;
  ViewHeight: Single;
  ViewWidth: Single;
begin
  inherited;
  { This virtual method is executed every frame (many times per second). }
  if FRestarting then
    try
      BeginOfTurn();
    except
      on E: Exception do
        raise Exception.Create('Failed to beggin the turn: ' + E.Message);
    end;

  { If player is dead and we did not show game over view we do that }
  if (PlayersAlive() = 0) and (Container.FrontView <> ViewGameOver) then
  begin
    try
      EndOfTurn();
    except
      on E: Exception do
        raise Exception.Create('Failed to end the turn: ' + E.Message);
    end;
    Exit;
  end;

  var LBestPlayer := FurtherPlayer();
  if not Assigned(LBestPlayer) then
    Exit;

  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;

  ViewHeight := MainViewport.Camera.Orthographic.EffectiveRect.Height;
  ViewWidth := MainViewport.Camera.Orthographic.EffectiveRect.Width;

  CamPos := MainViewport.Camera.Translation;
  CamPos.X := LBestPlayer.Translation.X;
  CamPos.Y := LBestPlayer.Translation.Y;

  { Camera always stay on level }
  if CamPos.Y - ViewHeight / 2 < LevelBounds.Down then
     CamPos.Y := LevelBounds.Down + ViewHeight / 2;

  if CamPos.Y + ViewHeight / 2 > LevelBounds.Top then
     CamPos.Y := LevelBounds.Top - ViewHeight / 2;

  if CamPos.X - ViewWidth / 2 < LevelBounds.Left then
     CamPos.X := LevelBounds.Left + ViewWidth / 2;

  if CamPos.X + ViewWidth / 2 > LevelBounds.Right then
     CamPos.X := LevelBounds.Right - ViewWidth / 2;

  MainViewport.Camera.Translation := CamPos;
end;

function TViewPlay.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if Result then Exit; // allow the ancestor to handle keys

  { This virtual method is executed when user presses
    a key, a mouse button, or touches a touch-screen.

    Note that each UI control has also events like OnPress and OnClick.
    These events can be used to handle the "press", if it should do something
    specific when used in that UI control.
    The TViewPlay.Press method should be used to handle keys
    not handled in children controls.
  }

  if Event.IsKey(keyF5) then
  begin
    Container.SaveScreenToDefaultFile;
    Exit(true);
  end;

  if Event.IsKey(keyEscape) and (Container.FrontView = ViewPlay) then
  begin
    PauseGame;
    Container.PushView(ViewPause);
    Exit(true);
  end;
end;

end.
