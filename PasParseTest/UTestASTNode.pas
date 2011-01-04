unit UTestASTNode;

interface

uses
  UTest, UTokenType, UToken;

type
  TTestASTNode = class(TTest)
  private
    /// Creates a testing token.
    ///  Callers are responsible for destroying the resulting TToken instance!
    class function MakeToken(ATokenType: TTokenType; AText: string): TToken;
    /// Tests if TToken.Inspect() works as expected
    class function TestInspectToken: Boolean;
    /// Tests if TBinaryOperationNode.Inspect() works as expected
    class function TestInspectBinaryOperationNode: Boolean;

  protected
    class procedure TestAll; override;
    class function GetName: string; override;
  end;

implementation

uses
  UASTNode, ULocation, UBinaryOperationNode;

{ TTestASTNode }

class function TTestASTNode.GetName: string;
begin
  Result := 'ASTNode';
end;

class function TTestASTNode.MakeToken(ATokenType: TTokenType;
  AText: string): TToken;
begin
  Result := TToken.Create(ATokenType, TLocation.Create('', '', 0), AText, '');
end;

class procedure TTestASTNode.TestAll;
begin
  OK('InspectToken', TestInspectToken);
  OK('InspectBinaryOperationNode', TestInspectBinaryOperationNode);
end;

class function TTestASTNode.TestInspectBinaryOperationNode: Boolean;
var
  ALeft: TASTNode;
  AOp: TToken;
  ARight: TASTNode;
  ANode: TASTNode;
begin
  ALeft := MakeToken(TTNumber, '6');
  AOp := MakeToken(TTTimesSign, '*');
  ARight := MakeToken(TTNumber, '9');
  ANode := TBinaryOperationNode.Create(ALeft, AOp, ARight);
  Result := (ANode.Inspect = 'BinaryOperationNode' + #13#10 +
    '  LeftNode: Number |6|' + #13#10 + '  OperatorNode: TimesSign |*|' +
    #13#10 + '  RightNode: Number |9|');
  ANode.Free;
  ALeft.Free;
  AOp.Free;
  ARight.Free;
end;

class function TTestASTNode.TestInspectToken: Boolean;
var
  ANode: TASTNode;
begin
  ANode := MakeToken(TTNumber, '42');
  Result := (ANode.Inspect = 'Number |42|');
  ANode.Free;
end;

end.

