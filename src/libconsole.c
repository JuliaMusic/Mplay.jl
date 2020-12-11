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
typedef void (*sighandler_t)(int);
#endif

#define KEY_F1    290
#define KEY_F2    291
#define KEY_F3    292
#define KEY_F4    293
#define	KEY_RIGHT 262
#define	KEY_LEFT  263
#define	KEY_DOWN  264
#define	KEY_UP    265

#if defined(_WIN32)
static int code[] = {
    7, 0, 4, 2, 6, 1, 5, 3, 7, 8, 12, 10, 14, 9, 13, 11, 15
};
#else
static char *code[] = {
    "\033[m",
    "\033[30m", "\033[31m", "\033[32m", "\033[33m", "\033[34m", "\033[35m", "\033[36m", "\033[37m",
    "\033[90m", "\033[91m", "\033[92m", "\033[93m", "\033[94m", "\033[95m", "\033[96m", "\033[97m",
};
#endif

#if defined(_WIN32)
static HANDLE std_input, std_output = (HANDLE) NULL;
static DWORD saved_console_mode;
static CONSOLE_CURSOR_INFO saved_cursor_info;
#else
static struct termios saved_term;
static sighandler_t saved_handler = NULL;
#endif

void resettty(void)
{
#if defined(_WIN32)
    COORD cursor = { 0, 0 };

    if (std_output != NULL) {
        SetConsoleCursorInfo(std_output, &saved_cursor_info);
        SetConsoleCursorPosition(std_output, cursor);
        SetConsoleMode(std_output, saved_console_mode);
    }
#else
    if (saved_handler != NULL) {
        if (tcsetattr(0, TCSANOW, &saved_term) < 0)
            perror("tcsetattr");

        signal(SIGQUIT, saved_handler);
    }
#endif
}

void settty(void)
{
#if defined(_WIN32)
    COORD cursor = { 0, 0 };
    DWORD console_mode;
    CONSOLE_CURSOR_INFO cursor_info;

    if (std_output != NULL)
        return;

    std_input = GetStdHandle(STD_INPUT_HANDLE);
    std_output = GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleMode(std_input, &saved_console_mode);
    console_mode = saved_console_mode & ~ENABLE_PROCESSED_INPUT &
        ~ENABLE_LINE_INPUT & ~ENABLE_ECHO_INPUT;

    SetConsoleMode(std_input, console_mode);
    SetConsoleOutputCP(CP_UTF8);

    GetConsoleCursorInfo(std_output, &saved_cursor_info);
    cursor_info = saved_cursor_info;
    cursor_info.bVisible = FALSE;
    SetConsoleCursorInfo(std_output, &cursor_info);
#else
    struct termios term;

    if (saved_handler != NULL)
        return;

    if (tcgetattr(0, &saved_term) < 0)
        perror("tcgetattr");

    term = saved_term;
    term.c_cflag |= (CREAD | CS8 | CLOCAL);
    term.c_lflag &= ~(ECHO | ICANON | ISIG);
    term.c_iflag &= ~(IGNCR | INLCR | ICRNL);

    if (tcsetattr(0, TCSAFLUSH, &term) < 0)
        perror("tcsetattr");

    saved_handler = signal(SIGQUIT, (void (*) (int))resettty);
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
                    case VK_UP: key = KEY_UP; break;
                    case VK_LEFT: key = KEY_LEFT; break;
                    case VK_DOWN: key = KEY_DOWN; break;
                    case VK_RIGHT: key = KEY_RIGHT; break;
                    case VK_F1: key = KEY_F1; break;
                    case VK_F2: key = KEY_F2; break;
                    case VK_F3: key = KEY_F3; break;
                    case VK_F4: key = KEY_F4; break;
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
                        case 'A': key = KEY_UP; break;
                        case 'B': key = KEY_DOWN; break;
                        case 'C': key = KEY_RIGHT; break;
                        case 'D': key = KEY_LEFT; break;
                        case 'P': key = KEY_F1; break;
                        case 'Q': key = KEY_F2; break;
                        case 'R': key = KEY_F3; break;
                        case 'S': key = KEY_F4; break;
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

void outtextxy(int x, int y, char *s, int color)
{
#if defined(_WIN32)
    wchar_t w_s[255];
    COORD cursor;

    cursor.X = x - 1;
    cursor.Y = y - 1;
    SetConsoleCursorPosition(std_output, cursor);

    SetConsoleTextAttribute(std_output, code[color]);

    MultiByteToWideChar(CP_UTF8, 0, s, strlen(s) + 1, w_s, 255);
    WriteConsoleW(std_output, w_s, lstrlenW(w_s), NULL, NULL);
#else
    if (color >= 1 && color <= 16)
        printf("\033[%d;%dH%s%s%s", y, x, code[color], s, code[0]);
    else
        printf("\033[%d;%dH%s", y, x, s);
    fflush(stdout);
#endif
}

void cls(void)
{
#if defined(_WIN32)
    CONSOLE_SCREEN_BUFFER_INFO info;
    COORD cursor = { 0, 0 };
    DWORD num_write;

    GetConsoleScreenBufferInfo(std_output, &info);
    FillConsoleOutputAttribute(std_output,
        FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE, 24 * 80, cursor,
        &num_write);
    FillConsoleOutputCharacter(std_output, ' ', info.dwSize.X * info.dwSize.Y, cursor, &num_write);
#else
    printf("\033[H\033[J");
    fflush(stdout);
#endif
}
