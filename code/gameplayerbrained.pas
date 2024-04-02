unit GamePlayerBrained;

interface

uses
  System.SysUtils,
  System.Classes,
  CastleTransform,
  GamePlayer,
  GameNeuralNetwork;

type
  TPlayerBrained = class(TPlayer)
  private const
    INPUT_LAYER_NEURON_COUNT = 2;
    HIDDEN_LAYER_NEURON_COUNT = 6;
    OUTPUT_LAYER_NEURON_COUNT = 2;
    HIDDEN_LAYER_COUNT = 1;
  private
    FBrain: TNeuralNetwork;
    FGeneticInfo: TGeneticInfo;
    FRun: boolean;
    FJump: boolean;
  protected
    function InputRight: Boolean; override;
    function InputJump: Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure ParentAfterAttach; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;

    procedure Setup(const AIndex: integer); override;

    property Brain: TNeuralNetwork read FBrain write FBrain;
    property GeneticInfo: TGeneticInfo read FGeneticInfo;
  end;

implementation

uses
  CastleComponentSerialize,
  CastleLog;

constructor TPlayerBrained.Create(AOwner: TComponent);
begin
  inherited;
  FBrain := TNeuralNetwork.Create(
    INPUT_LAYER_NEURON_COUNT,
    HIDDEN_LAYER_NEURON_COUNT,
    OUTPUT_LAYER_NEURON_COUNT,
    HIDDEN_LAYER_COUNT);
end;

destructor TPlayerBrained.Destroy;
begin
  FBrain.Free();
  inherited;
end;

function TPlayerBrained.InputRight: Boolean;
begin
  Result := FRun;
end;

function TPlayerBrained.InputJump: Boolean;
begin
  Result := FJump;
end;

procedure TPlayerBrained.ParentAfterAttach;
begin
  inherited;
  { Parent is available now. }
end;

procedure TPlayerBrained.Setup(const AIndex: integer);
begin
  inherited;
  FRun := false;
  FJump := false;
  FGeneticInfo.Fitness := 0;
  FGeneticInfo.DNA := TGeneticAlgorithm.Instance.Update(AIndex, FBrain);
end;

procedure TPlayerBrained.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  var LOutput := TNeuralNetwork.TOutput(nil);
  try
    LOutput := FBrain.Predict([
      EnemyBehind(),
      DeadlyObstacleAhead()
    ]);

    FRun := LOutput[0] > 0.0;
    FJump := (LOutput[1] > 0.0);
  except
    on E: Exception do
      raise Exception.Create('Failed to predict: ' + E.Message);
  end;

  //if FRun then
  //  WritelnLog('Run: ' + FRun.ToString(true))
  //else
    WritelnLog('Run: ' + LOutput[0].ToString());

  //if FJump then
  //  WritelnLog('Jump: ' + FJump.ToString(true))
  //else
    WritelnLog('Jump: ' + LOutput[1].ToString());

  inherited;

  FGeneticInfo.Fitness := FGeneticInfo.Fitness + 1;
end;

initialization
  { Optional: If you want to make this behavior available in the editor,
    add GamePlayerBrained to the editor_units="..." in CastleEngineManifest.xml
    and reopen the project.
    It will build a custom editor with this behavior available at design-time.
    See https://castle-engine.io/custom_components .

    Note that you don't *need* to do this.
    Even without any change to CastleEngineManifest.xml,
    you can use the new behavior class in code,
    e.g. create it in the view TMyView.Start method:

      MyPlayerBrained := TPlayerBrained.Create(FreeAtStop);
      MyTransform.AddBehavior(MyPlayerBrained);
  }
  RegisterSerializableComponent(TPlayerBrained, 'PlayerBrained');
end.
