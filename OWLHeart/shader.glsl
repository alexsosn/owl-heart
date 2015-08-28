varying highp vec2 textureCoordinate;

uniform sampler2D inputImageTexture;

void main()
{
    lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
    lowp vec4 outputColor;
    outputColor.r = textureColor.r;
    outputColor.g = 0.0;
    outputColor.b = 0.0;
    outputColor.a = 1.0;
    
    gl_FragColor = outputColor;
}