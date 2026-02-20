
{ pkgs, lib, ... }:
{
	# Prism Launcher Wrapper to force Nvidia GPU usage
	environment.systemPackages = [
		(pkgs.symlinkJoin {
			name = "prismlauncher-nvidia";
			paths = [ pkgs.prismlauncher ];
			buildInputs = [ pkgs.makeWrapper ];
			postBuild = ''
				wrapProgram $out/bin/prismlauncher \
					--set __NV_PRIME_RENDER_OFFLOAD 1 \
					--set __GLX_VENDOR_LIBRARY_NAME nvidia \
					--set DRI_PRIME 1 \
					--set __VK_LAYER_NV_optimus NVIDIA_only
			'';
		})
	];
}
