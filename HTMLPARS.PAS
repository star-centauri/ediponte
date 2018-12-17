unit HTMLPars;

interface

uses
  SysUtils, Classes;

type THTMLParam = class
     private
      fRaw:string;
      fKey:string;
      fValue:string;
      procedure SetKey(Key:string);
     public
      constructor Create;
      destructor Destroy; override;
     published
      property Key:string read fKey write SetKey;
      property Value:string read fValue;
      property Raw:string read fRaw;
     end;

type THTMLTag = class
     private
      fName:string;
      fRaw:string;
      procedure SetName(Name:string);
     public
      Params:TList;
      constructor Create;
      destructor Destroy; override;
     published
      property Name:string read fName write SetName; // uppercased TAG (without <>)
      property Raw:string read fRaw; // raw TAG (parameters included) as read from input file (without<>)
     end;

type THTMLText = class
     private
      fLine:String;
      fRawLine:string;
      procedure SetLine(Line:string);
     public
      constructor Create;
      destructor Destroy; override;
     published
      property Line:string read fLine write SetLine;   // HTML3.2 Entities and Western Latin-1 Font converted Text
      property Raw:string read fRawLine; // raw text line as read from input file
     end;

type THTMLParser = class(TObject)
     private
       Text:string;
       Tag:string;
       isTag:boolean;
       procedure AddText;
       procedure AddTag;
     public
       parsed:TList;
       Lines:TStringlist;
       constructor Create;
       destructor Destroy; override;
       procedure Execute;
     published
     end;

implementation



constructor THTMLParser.Create;
begin
 inherited Create;
 Lines:=TStringlist.Create;
 Parsed:=TList.Create;
end;

destructor THTMLParser.Destroy;
begin
 Lines.Free;
 Parsed.Free;
 inherited Destroy;
end;


procedure THTMLParser.AddText;
var HTMLText:THTMLText;

begin
 if not isTag then
  if Text<>'' then
   begin
    HTMLText:=THTMLText.Create;
    HTMLText.Line:=Text;
    Text:='';
    parsed.Add(HTMLText);
   end;
end;


procedure THTMLParser.AddTag;
var HTMLTag:THTMLTag;
begin
 isTag:=false;
 HTMLTag:=THTMLTag.Create;
 HTMLTag.Name:=Tag;
 Tag:='';
 parsed.Add(HTMLTag);
end;



procedure THTMLParser.Execute;
var i:integer;
    s:string;
begin
 Text:='';
 Tag:='';
 isTag:=false;
 for i:= 1 to Lines.Count do
  begin
   s:=Lines[i-1];
   while Length(s)>0 do
    begin
     if s[1]='<' then begin AddText;isTag:=true;end
     else
     if s[1]='>' then AddTag
     else
     if isTag then Tag:=Tag+s[1]
              else Text:=Text+s[1];
     delete(s,1,1);
    end;
   if (not isTag) and (Text<>'') then Text:=Text+#10;
  end;
 if (isTag) and (Tag<>'') then AddTag;
 if (not isTag) and (Text<>'') then AddText;
end;




constructor THTMLTag.Create;
begin
 inherited Create;
 Params:=Tlist.Create;
end;


destructor THTMLTag.Destroy;
var i:integer;
begin
 for i:= Params.Count downto 1 do
 begin
  THTMLparam(Params[i-1]).Free;
  Params.delete(i-1);
 end;
 Params.Free;
 inherited Destroy;
end;



procedure THTMLTag.SetName(Name:string);
var Tag:string;
    param:string;
    HTMLParam:THTMLParam;
    isQuote:boolean;
begin
 fRaw:=Name;
 Params.clear;

 while (Length(Name)>0) and (Name[1]<>' ') do
  begin
   Tag:=Tag+Name[1];
   Delete(Name,1,1);
  end;

 fName:=uppercase(Tag);

 while (Length(Name)>0) do
 begin
  param:='';
  isQuote:=false;
  while (Length(Name)>0) and ( not ((Name[1]=' ') and (isQuote=false))) do
   begin
    if Name[1]='"' then
    IsQuote:=not(IsQuote);
    param:=param+Name[1];
    Delete(Name,1,1);
   end;

  if (Length(Name)>0) and (Name[1]=' ') then Delete(Name,1,1);
  if param<>'' then
   begin
    HTMLParam:=THTMLParam.Create;
    HTMLParam.key:=param;
    params.add(HTMLParam);
   end;
 end;

end;


{$i latin1.pas}

procedure THTMLText.SetLine(Line:string);
var j,i:integer;
    isEntity:boolean;
    Entity:string;
    EnLen,EnPos:integer;
    d,c:integer;
begin
 fRawLine:=Line;
 while pos(#10,Line)>0 do Line[Pos(#10,Line)]:=' ';
 while pos('  ',Line)>0 do delete(Line,pos('  ',Line),1);

 i:=1;
 isEntity:=false;
 EnPos:=0;
 while (i<=Length(Line)) do
  begin
   if Line[i]='&' then begin EnPos:=i;isEntity:=true;Entity:='';end;
   if isEntity then Entity:=Entity+Line[i];
   if isEntity then
   if (Line[i]=';') or (Line[i]=' ') then begin
                         EnLen:=Length(Entity);

                         // charset encoded entity
                         if (EnLen>2) and (Entity[2]='#') then
                          begin
                           delete(Entity,EnLen,1); //delete the ;
                           delete(Entity,1,2); // delete the &#
                           if uppercase(Entity[1])='X' then Entity[1]:='$'; // it's hex (but not supported!!!)
                           if (Length(Entity)<=3) then // we cant convert e.g. cyrillic/chinise capitals
                            begin
                             val(Entity,d,c);
                             if c=0 then // conversion successful
                              begin
                               delete(Line,EnPos,EnLen);
                               insert(Charset[d],Line,EnPos);
                               i:=EnPos; // set new start
                              end;
                            end;
                          end
                          else
                          begin // its an entity
                           j:=1;
                           while (j<=100) do
                            begin
                             if Entity=(Entities[j,1]) then
                              begin
                               delete(Line,EnPos,EnLen);
                               insert(Entities[j,2],Line,Enpos);
                               j:=102; // stop searching
                              end;
                             j:=j+1;
                            end;
                          // reset Line
                          if j=103 then i:=EnPos-1
                                   else i:=EnPos;
                          end;

                         IsEntity:=false;
                       end;
   i:=i+1;
  end;

 fLine:=Line;
end;


procedure THTMLParam.SetKey(Key:string);
begin
 fValue:='';
 fRaw:=Key;
 if pos('=',key)<>0 then
  begin
   fValue:=Key;
   delete(fValue,1,pos('=',key));
   key:=copy(Key,1,pos('=',key)-1);

   if Length(fValue)>1 then
    if (fValue[1]='"') and (fValue[Length(fValue)]='"') then
     begin
      delete(fValue,1,1);
      delete(fValue,Length(fValue),1);
     end;
  end;
 fKey:=uppercase(key);
end;

constructor THTMLParam.Create;
begin
 inherited Create;
end;

destructor THTMLParam.Destroy;
begin
 inherited Destroy;
end;

constructor THTMLText.Create;
begin
 inherited Create;
end;

destructor THTMLText.Destroy;
begin
 inherited Destroy;
end;
end.
