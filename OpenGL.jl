module OpenGL

const libGL = Sys.KERNEL == :NT ? "C:/Windows/System32/opengl32.dll" : "/System/Library/Frameworks/OpenGL.framework/Versions/Current/Libraries/libGL.dylib"

@static if VERSION < v"0.7.0-DEV.3137"
  const Cvoid = Void
end

const GL_LINES = 0x0001
export GL_LINES
const GL_QUADS = 0x0007
export GL_QUADS
const GL_UNPACK_ALIGNMENT = 0x0CF5
export GL_UNPACK_ALIGNMENT
const GL_TEXTURE_2D = 0x0DE1
export GL_TEXTURE_2D
const GL_UNSIGNED_BYTE = 0x1401
export GL_UNSIGNED_BYTE
const GL_PROJECTION = 0x1701
export GL_PROJECTION
const GL_TEXTURE = 0x1702
export GL_TEXTURE
const GL_RGB = 0x1907
export GL_RGB
const GL_NEAREST = 0x2600
export GL_NEAREST
const GL_TEXTURE_MAG_FILTER = 0x2800
export GL_TEXTURE_MAG_FILTER
const GL_TEXTURE_MIN_FILTER = 0x2801
export GL_TEXTURE_MIN_FILTER

const GLenum = Cuint
const GLvoid = Cvoid
const GLint = Cint
const GLuint = Cuint
const GLdouble = Cdouble
const GLsizei = Csize_t

function glBegin(mode)
    ccall((:glBegin, libGL),
          GLvoid,
          (GLenum,),
          mode)
end
export glBegin

function glEnd()
    ccall((:glEnd, libGL),
          GLvoid,
          ())
end
export glEnd

function glColor3d(red, green, blue)
    ccall((:glColor3d, libGL),
          GLvoid,
          (GLdouble, GLdouble, GLdouble),
          red, green, blue)
end
export glColor3d

function glLoadIdentity()
    ccall((:glLoadIdentity, libGL),
          GLvoid,
          ())
end
export glLoadIdentity

function glMatrixMode(mode)
    ccall((:glMatrixMode, libGL),
          GLvoid,
          (GLenum,),
          mode)
end
export glMatrixMode

function glOrtho(left, right, bottom, top, zNear, zFar)
    ccall((:glOrtho, libGL),
          GLvoid,
          (GLdouble, GLdouble, GLdouble, GLdouble, GLdouble, GLdouble),
          left, right, bottom, top, zNear, zFar)
end
export glOrtho

function glScaled(x, y, z)
    ccall((:glScaled, libGL),
          GLvoid,
          (GLdouble, GLdouble, GLdouble),
          x, y, z)
end
export glScaled

function glPixelStorei(pname, param)
    ccall((:glPixelStorei, libGL),
          GLvoid,
          (GLenum, GLint),
          pname, param)
end
export glPixelStorei

function glVertex2i(x, y)
    ccall((:glVertex2i, libGL),
          GLvoid,
          (GLint, GLint),
          x, y)
end
export glVertex2i

function glGenTextures(n)
    textures = Cuint[1]
    ccall((:glGenTextures, libGL),
          GLvoid,
          (GLsizei, Ptr{GLuint}),
          n, textures)
    return textures[1]
end
export glGenTextures

function glBindTexture(target, texture)
    ccall((:glBindTexture, libGL),
          GLvoid,
          (GLenum, GLuint),
          target, texture)
end
export glBindTexture

function glTexImage2D(target, level, internalformat, width, height, border, format, type_, pixels)
    ccall((:glTexImage2D, libGL),
          GLvoid,
          (GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, Ptr{GLvoid}),
          target, level, internalformat, width, height, border, format, type_, pixels)
end
export glTexImage2D

function glTexParameteri(target, pname, param)
    ccall((:glTexParameteri, libGL),
          GLvoid,
          (GLenum, GLenum, GLint),
          target, pname, param)
end
export glTexParameteri

function glTexCoord2i(s, t)
    ccall((:glTexCoord2i, libGL),
          GLvoid,
          (GLint, GLint),
          s, t)
end
export glTexCoord2i

function glDisable(cap)
    ccall((:glDisable, libGL),
          GLvoid,
          (GLenum,),
          cap)
end
export glDisable

function glEnable(cap)
    ccall((:glEnable, libGL),
          GLvoid,
          (GLenum,),
          cap)
end
export glEnable

end
