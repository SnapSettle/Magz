{ lib, stdenv, fetchurl }:

let
  version = "0.0.1"; 
  owner = "snapsettle";
  repo = "magz";

  arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "amd64";

  url = "https://github.com/${owner}/${repo}/releases/download/v${version}/magz_${version}_linux_${arch}.tar.gz";
in
stdenv.mkDerivation rec {
  pname = "magz";
  inherit version;

  src = fetchurl {
    inherit url;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # Since the source is a pre-compiled binary, we don't need any build steps
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    cp magz $out/bin/
    chmod +x $out/bin/magz
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Magz - A web-based digital magazine and book library server";
    homepage = "https://github.com/${owner}/${repo}";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
