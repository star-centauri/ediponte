unit epConvert;

interface

uses
  dvcrt,
  dvwin,
  sysUtils,
  HTMLPars;

procedure htmlToText(var nomeArq: string);

implementation

procedure htmlToText(var nomeArq: string);
var
    arqDest: TextFile;
    i: integer;
    HTMLParser:THTMLParser;
    obj:TObject;
    emScript, emStyle: boolean;

begin

	assignFile (arqDest, '$$$temp$$$.txt');
	rewrite (arqDest);

    HTMLParser := THTMLParser.Create;
    HTMLParser.Lines.loadfromfile(nomeArq);
    HTMLParser.Execute;

    emScript := false;
    emStyle := false;

	for i:= 0 to HTMLParser.parsed.count-1 do
		begin
			obj:=HTMLParser.parsed[i];
			if obj.classtype = THTMLText then
               begin
                   if not (emScript or emStyle) then
        			   writeln(arqDest, THTMLText(obj).Line + ' ')
               end
			else
			if obj.classtype = THTMLTag then
			   begin
                   // writeln(THTMLTag(obj).Name);
                   if THTMLTag(obj).Name = 'STYLE' then
                       emStyle := true
                   else
                   if THTMLTag(obj).Name = '/STYLE' then
                       emStyle := false
                   else
                   if THTMLTag(obj).Name = 'SCRIPT' then
                       emScript := true
                   else
                   if THTMLTag(obj).Name = '/SCRIPT' then
                       emScript := false
                   else
                   if THTMLTag(obj).Name = 'BR' then
                       writeln (ArqDest)
                   else
                   if (THTMLTag(obj).Name = 'P') or
                      (THTMLTag(obj).Name = 'H1') or
                      (THTMLTag(obj).Name = '/H1') or
                      (THTMLTag(obj).Name = 'H2') or
                      (THTMLTag(obj).Name = '/H2') or
                      (THTMLTag(obj).Name = 'H3') or
                      (THTMLTag(obj).Name = '/H3') then
                           begin
                               writeln (ArqDest);
                               writeln (ArqDest);
                           end

                   else
                   if THTMLTag(obj).Name = 'IMG' then
                       writeln (ArqDest, '[-]');
               end;
		end;
	closeFile (arqDest);

	HTMLParser.Free;

    nomeArq := '$$$temp$$$.txt';
end;
end.
