This script is to be used to combine the different localized layers of a png
into a single png, along with locale information and showtime information.

python genbillboard.py --showtime <> <path-to-pictures>

The script will look for images in <path-to-pictures> for images in the form:

image_<resolution>_<index>_<base or locale>.png

where,

resolution is one of 1080p, 720p or 480p

index is one of 0, 1, 2,.. corresponding to the particular frame of billboard.
Index 0 corresponds to base image

The last component of the file name indicates whether it is the base image or
localized layer of the text in the image. For example, for every frame of
billboard image, there will be a base png and several pngs corresponding to the
different supported languages.

The script will take all of these pngs for a given resolution and combine them
int a single image of name image_<resolution>_<index>.png consisting of the base
image in the first layer and the lozalized text in subsequent layers.

The script will try to generate lower resolution pictures (720p and 480p) from
1080p if possible. So marketting has to atleast provide all the images needed
for 1080p resolution. However, prefer if they provide assets at all the
supported resolution.

The generated image for the billboard base needs to be checked into the below
path so they can be added to the base build:

${TOP}/device/nvidia/platform/t210/rescovery/res/images/billboard_installing_<resolution>_0.png

The generated frames of billboard need to be checked into the below path so
those can be added to the OTA package:

{TOP}/vendor/nvidia/loki/skus/foster/billboard/
