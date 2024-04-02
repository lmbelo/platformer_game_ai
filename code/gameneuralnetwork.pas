unit GameNeuralNetwork;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  TPrecision = single;
  TWeights = TArray<TPrecision>;

  TNeuron = class
  private
    FWeights: TWeights;
    FLoss: TPrecision;
    FOutput: TPrecision;
  public
    constructor Create(const AOutput: TPrecision); overload;
    constructor Create(const AWeightCount: integer; const ALoss,
      AOutput: TPrecision); overload;

    property Weights: TWeights read FWeights write FWeights;
    property Loss: TPrecision read FLoss write FLoss;
    property Output: TPrecision read FOutput write FOutput;
  end;

  TNeurons = TArray<TNeuron>;

  TLayer = class
  private
    FNeurons: TNeurons;
  public
    constructor Create(const ANeuronCount: integer; const ADefaultOutput: TPrecision); overload;
    constructor Create(const ANeuronCount: integer; const AWeightCount: integer;
      const ADefaultLoss, ADefaultOutput: TPrecision); overload;

    property Neurons: TNeurons read FNeurons write FNeurons;
  end;

  TLayers = TArray<TLayer>;

  TNeuralNetwork = class
  public type
    TInput = TArray<TPrecision>;
    TOutput = TArray<TPrecision>;
  private
    const BIAS = 1;
  private
    FInputLayer: TLayer;
    FHiddenLayers: TLayers;
    FOutputLayer: TLayer;
  public
    constructor Create(AInputLayerNeuronCount, AHiddenLayerNeuronCount,
      AOutputLayerNeuronCount: integer; const AHiddenLayerCount: integer = 1);
    destructor Destroy(); override;

    function GetWeights(): TWeights;

    procedure LoadWeights(AWeights: TWeights);

    function Predict(const AInput: TInput): TOutput;

    property InputLayer: TLayer read FInputLayer write FInputLayer;
    property HiddenLayers: TLayers read FHiddenLayers write FHiddenLayers;
    property OutputLayer: TLayer read FOutputLayer write FOutputLayer;
  end;

  TActivateFuntion = record
  public
    class function ReLU(const AValue: TPrecision): TPrecision; static;
  end;  

  TFitness = single;
  TDNA = TArray<TPrecision>;
  TDNAArray = TArray<TDNA>;

  PGeneticInfo = ^TGeneticInfo;
  TGeneticInfo = record
  public
    DNA: TDNA;
    Fitness: TFitness;
  end;

  TGeneticInfosRef = TArray<PGeneticInfo>;

  TGeneticAlgorithm = class
  private
    class var FInstance: TGeneticAlgorithm;
  private
    FDNAs: TDNAArray;
    function GetRandomValue(): TPrecision;    
  public
    class constructor Create();
    class destructor Destroy();
  
    procedure Initialize(const APopulationCount: integer);
    function Update(const AIndex: integer; const ABrain: TNeuralNetwork): TDNA;

    procedure RandomMutations(const AGeneticInfos: TGeneticInfosRef);

    property DNAs: TDNAArray read FDNAs;

    class property Instance: TGeneticAlgorithm read FInstance;
  end;

implementation

{ TActivateFuntion }

class function TActivateFuntion.ReLU(const AValue: TPrecision): TPrecision;
begin
  if (AValue < 0) then
    Exit(0);

  if (AValue < 10000) then
    Result := AValue
  else
    Result := 10000;
end;

{ TNeuron }

constructor TNeuron.Create(const AOutput: TPrecision);
begin
  FOutput := AOutput;
end;

constructor TNeuron.Create(const AWeightCount: integer; const ALoss,
  AOutput: TPrecision);
begin
  Create(AOutput);
  SetLength(FWeights, AWeightCount);
  for var I := 0 to AWeightCount - 1 do
    FWeights[I] := Random(MAXINT) mod 2000 - 1000;
  FLoss := ALoss;
end;

{ TLayer }

constructor TLayer.Create(const ANeuronCount: integer; const ADefaultOutput: TPrecision);
begin
  for var I := 0 to ANeuronCount - 1 do
    FNeurons := FNeurons + [TNeuron.Create(ADefaultOutput)]
end;

constructor TLayer.Create(const ANeuronCount, AWeightCount: integer;
  const ADefaultLoss, ADefaultOutput: TPrecision);
begin
  for var I := 0 to ANeuronCount - 1 do
    FNeurons := FNeurons + [TNeuron.Create(AWeightCount, ADefaultLoss, ADefaultOutput)]
end;

{ TNeuralNetwork }

constructor TNeuralNetwork.Create(AInputLayerNeuronCount,
  AHiddenLayerNeuronCount, AOutputLayerNeuronCount: integer;
  const AHiddenLayerCount: integer);
const
  DEFAULT_OUTPUT = 1;
  DEFAULT_LOSS = 0;
begin
  Inc(AInputLayerNeuronCount, BIAS);
  Inc(AHiddenLayerNeuronCount, BIAS);

  FInputLayer := TLayer.Create(AInputLayerNeuronCount, DEFAULT_OUTPUT);

  FHiddenLayers := FHiddenLayers + [
    TLayer.Create(AHiddenLayerNeuronCount, AInputLayerNeuronCount, DEFAULT_LOSS, DEFAULT_OUTPUT)
  ];

  for var I := 1 to AHiddenLayerCount - 1 do
    FHiddenLayers := FHiddenLayers + [
      TLayer.Create(AHiddenLayerNeuronCount, AHiddenLayerNeuronCount, DEFAULT_LOSS, DEFAULT_OUTPUT)
    ];

  FOutputLayer := TLayer.Create(AOutputLayerNeuronCount, AHiddenLayerNeuronCount, DEFAULT_LOSS, DEFAULT_OUTPUT)
end;

destructor TNeuralNetwork.Destroy;
begin
  FOutputLayer.Free();
  for var LLayer in FHiddenLayers do
    LLayer.Free();
  FInputLayer.Free();
  inherited;
end;

function TNeuralNetwork.GetWeights: TWeights;
begin
  Result := nil;

  for var LLayer in FHiddenLayers do
    for var LNeuron in LLayer.Neurons do
      Result := Result + LNeuron.Weights;

  for var LNeuron in FOutputLayer.Neurons do
    Result := Result + LNeuron.Weights;
end;

procedure TNeuralNetwork.LoadWeights(AWeights: TWeights);
begin
  for var LLayer in FHiddenLayers do
    for var LNeuron in LLayer.Neurons do
      for var I := Low(LNeuron.Weights) to High(LNeuron.Weights) do
        LNeuron.Weights[I] := AWeights[I];

  for var LNeuron in FOutputLayer.Neurons do
    for var I := Low(LNeuron.Weights) to High(LNeuron.Weights) do
      LNeuron.Weights[I] := AWeights[I];  
end;

function TNeuralNetwork.Predict(const AInput: TInput): TOutput;
begin
  Assert(Length(AInput) = Length(FInputLayer.Neurons) - BIAS, 'Input shape mismatch.');

  // Update the input layers with inputs
  for var I := Low(FInputLayer.Neurons) to High(FInputLayer.Neurons) - BIAS do
    FInputLayer.Neurons[I].Output := AInput[I];  

  var LSum: TPrecision;
  // Calculate the output between the input layer and the first hidden layer
  for var I := Low(FHiddenLayers[0].Neurons) to High(FHiddenLayers[0].Neurons) - BIAS do begin
    LSum := 0;
    for var J := Low(FInputLayer.Neurons) to High(FInputLayer.Neurons) do
      LSum := LSum + FInputLayer.Neurons[J].Output * FHiddenLayers[0].Neurons[I].Weights[J];
    FHiddenLayers[0].Neurons[I].Output := TActivateFuntion.ReLU(LSum);
  end;

  // Calculate the output between the hidden layer K and K-1
  for var K := Low(FHiddenLayers) + 1 to High(FHiddenLayers) do
    for var I := Low(FHiddenLayers[K].Neurons) to High(FHiddenLayers[K].Neurons) - BIAS do begin
      LSum := 0;
      for var J := Low(FHiddenLayers[K - 1].Neurons) to High(FHiddenLayers[K - 1].Neurons) do
        LSum := LSum + FHiddenLayers[K - 1].Neurons[J].Output * FHiddenLayers[K].Neurons[I].Weights[J];
      FHiddenLayers[K].Neurons[I].Output := TActivateFuntion.ReLU(LSum);
    end;

  // Calculate the output between the output layer and the last hidden layer
  var K := High(FHiddenLayers);
  for var I := Low(FOutputLayer.Neurons) to High(FOutputLayer.Neurons) do begin
    LSum := 0;       
    for var J := Low(FHiddenLayers[K].Neurons) to High(FHiddenLayers[K].Neurons) do
      LSum := LSum + FHiddenLayers[K].Neurons[J].Output * FOutputLayer.Neurons[I].Weights[J];
      
    FOutputLayer.Neurons[I].Output := TActivateFuntion.ReLU(LSum);
  end;
  
  SetLength(Result, Length(FOutputLayer.Neurons));
  for var I := Low(FOutputLayer.Neurons) to High(FOutputLayer.Neurons) do
    Result[I] := FOutputLayer.Neurons[I].Output;
end;

{ TGeneticAlgorithm }

class constructor TGeneticAlgorithm.Create;
begin
  FInstance := TGeneticAlgorithm.Create();
end;

class destructor TGeneticAlgorithm.Destroy;
begin
  FInstance.Free();
end;

function TGeneticAlgorithm.GetRandomValue: TPrecision;
begin
  Result := (Random(MAXINT) mod 20001 div 10) - 1000;
end;

procedure TGeneticAlgorithm.Initialize(const APopulationCount: integer);
begin
  SetLength(FDNAs, APopulationCount);
end;

function TGeneticAlgorithm.Update(const AIndex: integer; 
  const ABrain: TNeuralNetwork): TDNA;
begin
  if not Assigned(FDNAs[AIndex]) then begin
    SetLength(FDNAs[AIndex], Length(ABrain.GetWeights()));
    for var I := Low(FDNAs[AIndex]) to High(FDNAs[AIndex]) do
      FDNAs[AIndex][I] := GetRandomValue();
  end;
  
  ABrain.LoadWeights(FDNAs[AIndex]);

  Result := FDNAs[AIndex];
end;

procedure TGeneticAlgorithm.RandomMutations(const AGeneticInfos: TGeneticInfosRef);
var
  LGeneticInfos: TGeneticInfosRef;
begin
  Assert(Assigned(AGeneticInfos), 'Argument "AGeneticInfos" not assigned.');  

  var LRangeRandom := Length(AGeneticInfos[0].DNA);

  SetLength(LGeneticInfos, Length(AGeneticInfos));
  TArray.Copy<PGeneticInfo>(AGeneticInfos, LGeneticInfos, Length(AGeneticInfos));

  // Sort fitness
  for var I := Low(LGeneticInfos) to High(LGeneticInfos) do
    for var J := Low(LGeneticInfos) to High(LGeneticInfos) - 1 do
      if LGeneticInfos[J].Fitness < LGeneticInfos[J + 1].Fitness then begin
        var LTemp := LGeneticInfos[J];
        LGeneticInfos[J] := LGeneticInfos[J + 1];
        LGeneticInfos[J + 1] := LTemp;      
      end;
      
  // Clone DNAs
  var LStep := 5;
  var I := 0;
  while I < LStep do begin
    var J := LStep + I;
    while J < Length(LGeneticInfos) do begin     
      LGeneticInfos[J].DNA := LGeneticInfos[I].DNA;      
      J := J + LStep;  
    end;

    Inc(I);
  end;

  for var J := LStep to High(LGeneticInfos) do begin
    var LMutations := (Random(MAXINT) mod LRangeRandom) + 1;
    for var K := 0 to LMutations - 1 do begin
      var LKind := Random(MAXINT) mod 3;
      var LIndex := Random(MAXINT) mod Length(LGeneticInfos[J].DNA);
      case LKind of
        0: begin // Random values          
          LGeneticInfos[J].DNA[LIndex] := GetRandomValue()
        end;
        1: begin //Random mul
          var LNumber := (Random(MAXINT) mod 10001) / 10000 + 5;
          LGeneticInfos[J].DNA[LIndex] := LGeneticInfos[J].DNA[LIndex] * LNumber;
        end;
        2: begin //Random sum 
          var LNumber := GetRandomValue() / 100;
          LGeneticInfos[J].DNA[LIndex] := LGeneticInfos[J].DNA[LIndex] + LNumber;
        end;
        else
          raise Exception.Create('Invalid kind.');
      end;
    end;
  end; 

  // Copy new DNAs
  for var J := Low(AGeneticInfos) to High(AGeneticInfos) do
    FDNAs[J] := AGeneticInfos[J].DNA;
         
  // Reset fitness
  for I := Low(AGeneticInfos) to High(AGeneticInfos) do
    AGeneticInfos[I].Fitness := 0.0;
end;

end.
