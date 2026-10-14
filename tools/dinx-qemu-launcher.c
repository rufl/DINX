#define UNICODE
#define _UNICODE

#include <stdio.h>
#include <string.h>
#include <wchar.h>
#include <windows.h>

static void print_usage(void) {
    puts("DINX Windows QEMU launcher");
    puts("");
    puts("Usage:");
    puts("  dinx.exe                 Run the visual QEMU smoke test");
    puts("  dinx.exe --visual-test   Run the visual QEMU smoke test");
    puts("  dinx.exe --package-smoke Run the bounded headless package smoke test");
    puts("  dinx.exe --help          Show this help");
}

static BOOL file_exists(const wchar_t *path) {
    DWORD attributes = GetFileAttributesW(path);
    return attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

static BOOL copy_existing_path(
    wchar_t *destination,
    size_t destination_capacity,
    const wchar_t *candidate
) {
    size_t length = wcslen(candidate);
    if (length >= destination_capacity || !file_exists(candidate)) {
        return FALSE;
    }
    memcpy(destination, candidate, (length + 1) * sizeof(destination[0]));
    return TRUE;
}

static BOOL get_environment_value(
    const wchar_t *name,
    wchar_t *value,
    size_t value_capacity
) {
    DWORD length = GetEnvironmentVariableW(name, value, (DWORD)value_capacity);
    return length > 0 && length < value_capacity;
}

static BOOL find_powershell(wchar_t *path, size_t path_capacity) {
    DWORD length = SearchPathW(
        NULL,
        L"powershell.exe",
        NULL,
        (DWORD)path_capacity,
        path,
        NULL
    );
    if (length > 0 && length < path_capacity && file_exists(path)) {
        return TRUE;
    }

    wchar_t windows_directory[32768];
    UINT windows_length = GetWindowsDirectoryW(
        windows_directory,
        sizeof(windows_directory) / sizeof(windows_directory[0])
    );
    if (windows_length > 0 &&
        windows_length < sizeof(windows_directory) / sizeof(windows_directory[0])) {
        wchar_t candidate[32768];
        int candidate_length = swprintf(
            candidate,
            sizeof(candidate) / sizeof(candidate[0]),
            L"%ls\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
            windows_directory
        );
        if (candidate_length >= 0 &&
            (size_t)candidate_length < sizeof(candidate) / sizeof(candidate[0]) &&
            copy_existing_path(path, path_capacity, candidate)) {
            return TRUE;
        }
    }

    length = SearchPathW(
        NULL,
        L"pwsh.exe",
        NULL,
        (DWORD)path_capacity,
        path,
        NULL
    );
    if (length > 0 && length < path_capacity && file_exists(path)) {
        return TRUE;
    }

    wchar_t base_directory[32768];
    wchar_t candidate[32768];
    if (get_environment_value(
            L"ProgramFiles",
            base_directory,
            sizeof(base_directory) / sizeof(base_directory[0])
        )) {
        int candidate_length = swprintf(
            candidate,
            sizeof(candidate) / sizeof(candidate[0]),
            L"%ls\\PowerShell\\7\\pwsh.exe",
            base_directory
        );
        if (candidate_length >= 0 &&
            (size_t)candidate_length < sizeof(candidate) / sizeof(candidate[0]) &&
            copy_existing_path(path, path_capacity, candidate)) {
            return TRUE;
        }
    }

    if (get_environment_value(
            L"LOCALAPPDATA",
            base_directory,
            sizeof(base_directory) / sizeof(base_directory[0])
        )) {
        int candidate_length = swprintf(
            candidate,
            sizeof(candidate) / sizeof(candidate[0]),
            L"%ls\\Programs\\PowerShell\\7\\pwsh.exe",
            base_directory
        );
        if (candidate_length >= 0 &&
            (size_t)candidate_length < sizeof(candidate) / sizeof(candidate[0]) &&
            copy_existing_path(path, path_capacity, candidate)) {
            return TRUE;
        }
    }

    return FALSE;
}

static int run_test(const wchar_t *mode, BOOL visual) {
    wchar_t module_path[32768];
    DWORD module_length = GetModuleFileNameW(NULL, module_path, sizeof(module_path) / sizeof(module_path[0]));
    if (module_length == 0 || module_length >= sizeof(module_path) / sizeof(module_path[0])) {
        fputs("dinx: cannot resolve the launcher directory\n", stderr);
        return 1;
    }

    wchar_t *separator = wcsrchr(module_path, L'\\');
    if (separator == NULL) {
        fputs("dinx: launcher path has no directory\n", stderr);
        return 1;
    }
    *separator = L'\0';

    wchar_t powershell_path[32768];
    if (!find_powershell(
            powershell_path,
            sizeof(powershell_path) / sizeof(powershell_path[0])
        )) {
        fputs(
            "dinx: PowerShell was not found (tried powershell.exe and pwsh.exe)\n",
            stderr
        );
        return 1;
    }

    wchar_t script_path[32768];
    int script_length = swprintf(
        script_path,
        sizeof(script_path) / sizeof(script_path[0]),
        L"%ls\\dinx-visual-test.ps1",
        module_path
    );
    if (script_length < 0 || (size_t)script_length >= sizeof(script_path) / sizeof(script_path[0])) {
        fputs("dinx: visual test script path is too long\n", stderr);
        return 1;
    }

    wchar_t command_line[32768];
    int command_length = swprintf(
        command_line,
        sizeof(command_line) / sizeof(command_line[0]),
        L"\"%ls\" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"%ls\" -Mode %ls",
        powershell_path,
        script_path,
        mode
    );
    if (command_length < 0 || (size_t)command_length >= sizeof(command_line) / sizeof(command_line[0])) {
        fputs("dinx: PowerShell command line is too long\n", stderr);
        return 1;
    }

    STARTUPINFOW startup = {0};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESHOWWINDOW;
    startup.wShowWindow = visual ? SW_SHOWNORMAL : SW_HIDE;

    PROCESS_INFORMATION process = {0};
    DWORD creation_flags = visual ? 0 : CREATE_NO_WINDOW;
    BOOL created = CreateProcessW(
        powershell_path,
        command_line,
        NULL,
        NULL,
        FALSE,
        creation_flags,
        NULL,
        module_path,
        &startup,
        &process
    );
    if (!created) {
        fprintf(stderr, "dinx: cannot start PowerShell (Windows error %lu)\n", GetLastError());
        return 1;
    }

    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exit_code = 1;
    GetExitCodeProcess(process.hProcess, &exit_code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return exit_code <= 125 ? (int)exit_code : 1;
}

int main(int argc, char **argv) {
    if (argc > 2) {
        print_usage();
        return 2;
    }
    if (argc == 2 && strcmp(argv[1], "--help") == 0) {
        print_usage();
        return 0;
    }
    if (argc == 2 && strcmp(argv[1], "--version") == 0) {
        puts("DINX QEMU launcher 0.1.0");
        return 0;
    }
    if (argc == 2 && strcmp(argv[1], "--package-smoke") == 0) {
        return run_test(L"Smoke", FALSE);
    }
    if (argc == 1 || (argc == 2 && strcmp(argv[1], "--visual-test") == 0)) {
        return run_test(L"Visual", TRUE);
    }

    print_usage();
    return 2;
}
