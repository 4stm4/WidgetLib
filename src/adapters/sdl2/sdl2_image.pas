unit SDL2_image;

{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

uses
  SDL2;

function IMG_Init(flags: Integer): Integer; cdecl; external 'SDL2_image' name 'IMG_Init';
procedure IMG_Quit; cdecl; external 'SDL2_image' name 'IMG_Quit';

function IMG_Load(file_: PChar): PSDL_Surface; cdecl; external 'SDL2_image' name 'IMG_Load';
function IMG_Load_RW(src: Pointer; freesrc: Integer): PSDL_Surface; cdecl; external 'SDL2_image' name 'IMG_Load_RW';

const
  IMG_INIT_PNG  = $00000002;
  IMG_INIT_JPG  = $00000001;
  IMG_INIT_TIF  = $00000004;

implementation

{$linklib SDL2_image}

end.
