#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

out vec4 finalColor;

void main() {

    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);

    finalColor = texelColor * colDiffuse;

}
