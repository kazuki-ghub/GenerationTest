// ユーザ権限管理のサンプル
// 4種類の基本レベルと10個のカスタムレベルを定義
// 最大128ユーザを自前で管理する
// パスワードの有効期限や権限チェックをプログラムで実装
// CODESYSの標準機能を使わずに構成する
// アクセスレベルの列挙型
TYPE AccessLevel : (
    Guest := 0,
    Operator := 1,
    Supervisor := 2,
    Administrator := 3,
    Custom0 := 4,
    Custom1 := 5,
    Custom2 := 6,
    Custom3 := 7,
    Custom4 := 8,
    Custom5 := 9,
    Custom6 := 10,
    Custom7 := 11,
    Custom8 := 12,
    Custom9 := 13
);
END_TYPE
// 実行可能なアクションの列挙型
TYPE ActionID : (
    ScreenSwitch := 0,
    StartOperation := 1,
    ClearCounter := 2,
    ResetFault := 3,
    ManualOperation := 4,
    ProductChangeover := 5,
    ModifyProductSetting := 6,
    CopyProductSetting := 7,
    ClearFaultHistory := 8,
    ChangeSystemSetting := 9,
    ChangeTime := 10,
    UserRegistration := 11
);
END_TYPE

// 各アクションに対する権限を示す構造体
TYPE AccessRights : STRUCT
    ScreenSwitch : BOOL;
    StartOperation : BOOL;
    ClearCounter : BOOL;
    ResetFault : BOOL;
    ManualOperation : BOOL;
    ProductChangeover : BOOL;
    ModifyProductSetting : BOOL;
    CopyProductSetting : BOOL;
    ClearFaultHistory : BOOL;
    ChangeSystemSetting : BOOL;
    ChangeTime : BOOL;
    UserRegistration : BOOL;
END_STRUCT
END_TYPE

// ユーザ情報を保持する構造体
TYPE UserAccount : STRUCT
    UserName : STRING[32];
    Access : AccessLevel;
    Password : STRING[32];
    PrevPassword : STRING[32];
    DaysSinceChange : UDINT;
    Enabled : BOOL;
END_STRUCT
END_TYPE

// グローバル変数定義
VAR_GLOBAL
    Users : ARRAY[0..127] OF UserAccount;
    AccessTable : ARRAY[0..13] OF AccessRights; // AccessLevel列挙型に対応する権限テーブル
    LoggedInUser : INT := -1; // ログインしていない場合は-1
    PasswordExpiring : BOOL := FALSE; // パスワード期限警告用フラグ
END_VAR

// 起動時に一度だけ権限を初期化
PROGRAM InitAccessRights
VAR
END_VAR
AccessTable[AccessLevel.Guest].ScreenSwitch := TRUE;

AccessTable[AccessLevel.Operator] := AccessTable[AccessLevel.Guest];
AccessTable[AccessLevel.Operator].StartOperation := TRUE;
AccessTable[AccessLevel.Operator].ClearCounter := TRUE;
AccessTable[AccessLevel.Operator].ResetFault := TRUE;
AccessTable[AccessLevel.Operator].ManualOperation := TRUE;
AccessTable[AccessLevel.Operator].ProductChangeover := TRUE;

AccessTable[AccessLevel.Supervisor] := AccessTable[AccessLevel.Operator];
AccessTable[AccessLevel.Supervisor].ModifyProductSetting := TRUE;
AccessTable[AccessLevel.Supervisor].CopyProductSetting := TRUE;
AccessTable[AccessLevel.Supervisor].ClearFaultHistory := TRUE;
AccessTable[AccessLevel.Supervisor].ChangeSystemSetting := TRUE;
AccessTable[AccessLevel.Supervisor].ChangeTime := TRUE;

AccessTable[AccessLevel.Administrator] := AccessTable[AccessLevel.Supervisor];
AccessTable[AccessLevel.Administrator].UserRegistration := TRUE;

// ログインユーザの権限確認
FUNCTION HasPermission : BOOL
VAR_INPUT
    UserID : INT;
    Act : ActionID;
END_VAR
VAR
    rights : AccessRights;
END_VAR
IF (UserID < 0) OR (UserID > 127) THEN
    HasPermission := FALSE;
    RETURN;
END_IF
IF NOT Users[UserID].Enabled THEN
    HasPermission := FALSE;
    RETURN;
END_IF
rights := AccessTable[INT_TO_UINT(Users[UserID].Access)];
CASE Act OF
    ActionID.ScreenSwitch:       HasPermission := rights.ScreenSwitch;
    ActionID.StartOperation:     HasPermission := rights.StartOperation;
    ActionID.ClearCounter:       HasPermission := rights.ClearCounter;
    ActionID.ResetFault:         HasPermission := rights.ResetFault;
    ActionID.ManualOperation:    HasPermission := rights.ManualOperation;
    ActionID.ProductChangeover:  HasPermission := rights.ProductChangeover;
    ActionID.ModifyProductSetting: HasPermission := rights.ModifyProductSetting;
    ActionID.CopyProductSetting: HasPermission := rights.CopyProductSetting;
    ActionID.ClearFaultHistory:  HasPermission := rights.ClearFaultHistory;
    ActionID.ChangeSystemSetting:HasPermission := rights.ChangeSystemSetting;
    ActionID.ChangeTime:         HasPermission := rights.ChangeTime;
    ActionID.UserRegistration:   HasPermission := rights.UserRegistration;
    ELSE
        HasPermission := FALSE;
END_CASE

// ログイン処理FB
FUNCTION_BLOCK FB_Login
VAR_INPUT
    UserID : INT;
    Password : STRING[32];
END_VAR
VAR_OUTPUT
    Success : BOOL;
END_VAR
VAR
END_VAR
IF (UserID >= 0) AND (UserID <= 127) THEN
    IF Users[UserID].Enabled AND (Users[UserID].Password = Password) THEN
        IF Users[UserID].DaysSinceChange > 1000 THEN
            Users[UserID].Enabled := FALSE; // 永久に無効化
            Success := FALSE;
        ELSE
            LoggedInUser := UserID;
            Success := TRUE;
            IF Users[UserID].DaysSinceChange >= 820 THEN
                PasswordExpiring := TRUE; // 警告フラグ
            ELSE
                PasswordExpiring := FALSE;
            END_IF
        END_IF
    ELSE
        Success := FALSE;
    END_IF
ELSE
    Success := FALSE;
END_IF
END_FUNCTION_BLOCK

// ログアウト処理
PROGRAM Logout
VAR
END_VAR
LoggedInUser := -1;
PasswordExpiring := FALSE;
END_PROGRAM

// パスワード変更(本人のみ)
FUNCTION ChangePassword : BOOL
VAR_INPUT
    UserID : INT;
    OldPass : STRING[32];
    NewPass : STRING[32];
END_VAR
IF (LoggedInUser = UserID) AND (UserID >=0) AND (UserID <=127) THEN
    IF Users[UserID].Enabled AND (Users[UserID].Password = OldPass) THEN
        Users[UserID].PrevPassword := Users[UserID].Password;
        Users[UserID].Password := NewPass;
        Users[UserID].DaysSinceChange := 0;
        ChangePassword := TRUE;
    ELSE
        ChangePassword := FALSE;
    END_IF
ELSE
    ChangePassword := FALSE;
END_IF
END_FUNCTION

// 新規ユーザ作成(管理者のみ)
FUNCTION CreateUser : BOOL
VAR_INPUT
    RequestUser : INT; // Administrator権限必須
    NewID : INT;
    Name : STRING[32];
    Level : AccessLevel;
    TempPassword : STRING[32];
END_VAR
IF (RequestUser >=0) AND (RequestUser <=127) AND
   (Users[RequestUser].Access = AccessLevel.Administrator) THEN
    IF (NewID >=0) AND (NewID <=127) THEN
        Users[NewID].UserName := Name;
        Users[NewID].Access := Level;
        Users[NewID].Password := TempPassword;
        Users[NewID].PrevPassword := '';
        Users[NewID].DaysSinceChange := 0;
        Users[NewID].Enabled := TRUE;
        CreateUser := TRUE;
    ELSE
        CreateUser := FALSE;
    END_IF
ELSE
    CreateUser := FALSE;
END_IF
END_FUNCTION

// ユーザ削除処理(管理者のみ)
FUNCTION DeleteUser : BOOL
VAR_INPUT
    RequestUser : INT;
    TargetID : INT;
END_VAR
IF (RequestUser >=0) AND (RequestUser <=127) AND
   (Users[RequestUser].Access = AccessLevel.Administrator) THEN
    IF (TargetID >=0) AND (TargetID <=127) THEN
        Users[TargetID].Enabled := FALSE;
        Users[TargetID].UserName := '';
        Users[TargetID].Password := '';
        Users[TargetID].PrevPassword := '';
        Users[TargetID].DaysSinceChange := 0;
        DeleteUser := TRUE;
    ELSE
        DeleteUser := FALSE;
    END_IF
ELSE
    DeleteUser := FALSE;
END_IF
END_FUNCTION

// パスワード経過日数を日次更新
PROGRAM IncrementDay
VAR
    i : INT;
END_VAR
FOR i := 0 TO 127 DO
    IF Users[i].Enabled THEN
        Users[i].DaysSinceChange := Users[i].DaysSinceChange + 1;
        IF Users[i].DaysSinceChange > 1000 THEN
            Users[i].Enabled := FALSE; // 永久に無効化
        END_IF
    END_IF
END_FOR
END_PROGRAM
