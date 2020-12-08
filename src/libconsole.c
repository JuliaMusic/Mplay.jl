/*
 macOS:
   cc -shared -o libconsole.dylib libconsole.c
 Windows:
   cl /c libconsole.c
   link /out:libconsole.dll libconsole.obj
 */

#if defined(_WIN32)
#include <windows.h>
#include <commdlg.h>
#else
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include <signal.h>
#endif

#define F1 315
#define F2 316
#define F3 317
#define F4 318
#define UP 328
#define LEFT 331
#define RIGHT 333
#define DOWN 336

#if defined(_WIN32)
static HANDLE std_input, std_output = (HANDLE) NULL;
static DWORD saved_console_mode, console_mode;
#else
static struct termios Iterm, *pIterm = NULL;
#endif

void resettty(void)
{
#if defined(_WIN32)
    COORD cursor = { 0, 0 };

    if (std_output != NULL) {
        SetConsoleCursorPosition(std_output, cursor);
        SetConsoleMode(std_output, saved_console_mode);
    }
#else
    if (pIterm != NULL) {
        pIterm = NULL;
        if (tcsetattr(0, TCSANOW, &Iterm) < 0)
            perror("tcsetattr");
    }
#endif
}

void settty(void)
{
#if defined(_WIN32)
    COORD cursor = { 0, 0 };

    if (std_output != NULL)
        return;

    std_input = GetStdHandle(STD_INPUT_HANDLE);
    std_output = GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleMode(std_input, &saved_console_mode);
    console_mode = saved_console_mode & ~ENABLE_PROCESSED_INPUT &
        ~ENABLE_LINE_INPUT & ~ENABLE_ECHO_INPUT;

    SetConsoleMode(std_input, console_mode);
#else
    struct termios term;

    if (pIterm != NULL)
        return;

    if (tcgetattr(0, &Iterm) < 0)
        perror("tcgetattr");

    pIterm = &Iterm;
    term = Iterm;
    term.c_cflag |= (CREAD | CS8 | CLOCAL);
    term.c_lflag &= ~(ECHO | ICANON | ISIG);
    term.c_iflag &= ~(IGNCR | INLCR | ICRNL);

    if (tcsetattr(0, TCSAFLUSH, &term) < 0)
        perror("tcsetattr");

    signal(SIGHUP, (void (*) (int))resettty);
    signal(SIGQUIT, (void (*) (int))resettty);
    signal(SIGBUS, (void (*) (int))resettty);
    signal(SIGSEGV, (void (*) (int))resettty);
#endif
}

int kbhit(void)
{
#if defined(_WIN32)
    INPUT_RECORD input_event;
    DWORD num_read;

    PeekConsoleInput(std_input, &input_event, 1, &num_read);

    return num_read > 0 ? 1 : 0;
#else
    int readfds = 1 << 0;
    struct timeval timeout = {0, 0};

    return (select(1, (fd_set *) & readfds, (fd_set *) NULL, (fd_set *) NULL, &timeout) == 1);
#endif
}

unsigned int readchar(void)
{
    unsigned int key = 0;
#if defined(_WIN32)
    INPUT_RECORD input_event;
    DWORD num_read;

    ReadConsoleInput(std_input, &input_event, 1, &num_read);
    if (input_event.EventType == KEY_EVENT) {
        if (input_event.Event.KeyEvent.bKeyDown) {
            unsigned char ch;

            ch = input_event.Event.KeyEvent.uChar.AsciiChar;
            key = input_event.Event.KeyEvent.wVirtualKeyCode;

            if (ch == 0 || ch >= 0xe0 || key >= 0x60) {
                switch (key) {
                    case VK_UP: key = UP; break;
                    case VK_LEFT: key = LEFT; break;
                    case VK_DOWN: key = DOWN; break;
                    case VK_RIGHT: key = RIGHT; break;
                    case VK_F1: key = F1; break;
                    case VK_F2: key = F2; break;
                    case VK_F3: key = F3; break;
                    case VK_F4: key = F4; break;
                }
            } else
                key = ch;
        }
    }
#else
    unsigned char ch;

    if (read(0, &ch, 1) == 1) {
        if (ch == 27) {
            if (!kbhit()) {
                key = ch;
            } else if (read(0, &ch, 1) == 1) {
                if (ch == '[' || ch == 'O') {
                    if (read(0, &ch, 1) == 1) {
                        switch (ch) {
                        case 'A': key = UP; break;
                        case 'B': key = DOWN; break;
                        case 'C': key = RIGHT; break;
                        case 'D': key = LEFT; break;
                        case 'P': key = F1; break;
                        case 'Q': key = F2; break;
                        case 'R': key = F3; break;
                        case 'S': key = F4; break;
                        }
                    }
                }
            }
        } else
            key = ch;
    }
#endif
    return key;
}

void outtextxy(int x, int y, char *s)
{
#if defined(_WIN32)
    COORD cursor;
    DWORD num_write;

    cursor.X = x - 1;
    cursor.Y = y - 1;
    SetConsoleCursorPosition(std_output, cursor);

    SetConsoleTextAttribute(std_output, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
    WriteConsole(std_output, s, strlen(s), &num_write, NULL);
#else
    printf("\033[%d;%dH%s", y, x, s);
    fflush(stdout);
#endif
}

void cls(void)
{
#if defined(_WIN32)
    COORD cursor = { 0, 0 };
    DWORD num_write;

    FillConsoleOutputAttribute(std_output,
        FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE, 24 * 80, cursor,
        &num_write);
    FillConsoleOutputCharacter(std_output, ' ', 24 * 80, cursor, &num_write);
#else
    printf("\033[H\033[J");
    fflush(stdout);
#endif
}

