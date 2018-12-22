// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "tests_common.h"
#include <VFS/VFS.h>
#include <VFS/ArcLA.h>
#include <VFS/Native.h>

using namespace nc::vfs;
using namespace std;
using boost::filesystem::path;

static const auto g_Preffix = string(NCE(nc::env::test::ext_data_prefix)) + "archives/";
static const auto g_XNU   = g_Preffix + "xnu-2050.18.24.tar";
static const auto g_XNU2  = g_Preffix + "xnu-3248.20.55.tar";
static const auto g_Adium = g_Preffix + "adium.app.zip";
static const auto g_Angular = g_Preffix + "angular-1.4.0-beta.4.zip";
static const auto g_Files = g_Preffix + "files-1.1.0(1341).zip";
static const auto g_Encrypted = g_Preffix + "encrypted_archive_pass1.zip";
static const auto g_LZMA = g_Preffix + "lzma-4.32.7.tar.xz";
static const auto g_WarningArchive = g_Preffix + "maverix-master.zip";
static const auto g_ChineseArchive = g_Preffix + "GB18030.zip";
static const auto g_HeadingSlash = g_Preffix + "the.expanse.calibans.war.(2017).tv.s02.e13.eng.1cd.zip";
static const auto g_SlashDir = g_Preffix + "archive_with_slash_dir.zip";
static const auto g_GDriveDownload = g_Preffix + "gdrive_encoding.zip";


static int VFSCompareEntries(const path& _file1_full_path,
                             const VFSHostPtr& _file1_host,
                             const path& _file2_full_path,
                             const VFSHostPtr& _file2_host,
                             int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now
    
    VFSStat st1, st2;
    int ret;
    if((ret =_file1_host->Stat(_file1_full_path.c_str(), st1, VFSFlags::F_NoFollow, 0)) < 0)
        return ret;
    
    if((ret =_file2_host->Stat(_file2_full_path.c_str(), st2, VFSFlags::F_NoFollow, 0)) < 0)
        return ret;
    
    if((st1.mode & S_IFMT) != (st2.mode & S_IFMT)) {
        _result = -1;
        return 0;
    }
    
    if( S_ISREG(st1.mode) ) {
        if(int64_t(st1.size) - int64_t(st2.size) != 0)
            _result = int(int64_t(st1.size) - int64_t(st2.size));
    }
    else if( S_ISLNK(st1.mode) ) {
        char link1[MAXPATHLEN], link2[MAXPATHLEN];
        if( (ret = _file1_host->ReadSymlink(_file1_full_path.c_str(), link1, MAXPATHLEN, 0)) < 0)
            return ret;
        if( (ret = _file2_host->ReadSymlink(_file2_full_path.c_str(), link2, MAXPATHLEN, 0)) < 0)
            return ret;
        if( strcmp(link1, link2) != 0)
            _result = strcmp(link1, link2);
    }
    else if ( S_ISDIR(st1.mode) ) {
        _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
            int ret = VFSCompareEntries( _file1_full_path / _dirent.name,
                                        _file1_host,
                                        _file2_full_path / _dirent.name,
                                        _file2_host,
                                        _result);
            if(ret != 0)
                return false;
            return true;
        });
    }
    return 0;
}

@interface VFSArchive_Tests : XCTestCase

@end

@implementation VFSArchive_Tests

- (void)testXNUSource_TAR
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_XNU.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }

    XCTAssert( host->StatTotalDirs() == 246 );
    XCTAssert( host->StatTotalRegs() == 3288 );
    XCTAssert( host->IsDirectory("/", 0, 0) == true );
    XCTAssert( host->IsDirectory("/xnu-2050.18.24/EXTERNAL_HEADERS/mach-o/x86_64", 0, 0) == true );
    XCTAssert( host->IsDirectory("/xnu-2050.18.24/EXTERNAL_HEADERS/mach-o/x86_64/", 0, 0) == true );
    XCTAssert( host->Exists("/xnu-2050.18.24/2342423/9182391273/x86_64") == false );
    
    VFSStat st;
    XCTAssert( host->Stat("/xnu-2050.18.24/bsd/security/audit/audit_bsm_socket_type.c", st, 0, 0) == 0 );
    XCTAssert( st.mode_bits.reg );
    XCTAssert( st.size == 3313 );
    
    vector<string> filenames {
        "/xnu-2050.18.24/bsd/bsm/audit_domain.h",
        "/xnu-2050.18.24/bsd/netat/ddp_rtmp.c",
        "/xnu-2050.18.24/bsd/vm/vm_unix.c",
        "/xnu-2050.18.24/iokit/bsddev/DINetBootHook.cpp",
        "/xnu-2050.18.24/iokit/Kernel/x86_64/IOAsmSupport.s",
        "/xnu-2050.18.24/iokit/Kernel/IOSubMemoryDescriptor.cpp",
        "/xnu-2050.18.24/libkern/c++/Tests/TestSerialization/test2/test2.xcodeproj/project.pbxproj",
        "/xnu-2050.18.24/libkern/zlib/intel/inffastS.s",
        "/xnu-2050.18.24/osfmk/x86_64/pmap.c",
        "/xnu-2050.18.24/pexpert/gen/device_tree.c",
        "/xnu-2050.18.24/pexpert/i386/pe_init.c",
        "/xnu-2050.18.24/pexpert/pexpert/i386/efi.h",
        "/xnu-2050.18.24/security/mac_policy.h",
        "/xnu-2050.18.24/tools/lockstat/lockstat.c"
    };

    dispatch_group_t dg = dispatch_group_create();

    // massive concurrent access to archive
    for(int i = 0; i < 1000; ++i)
        dispatch_group_async(dg, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            string fn = filenames[ rand()%filenames.size() ];
            
            VFSStat st;
            XCTAssert( host->Stat(fn.c_str(), st, 0, 0) == 0 );
            
            VFSFilePtr file;
            XCTAssert( host->CreateFile(fn.c_str(), file, nullptr) == 0);
            XCTAssert( file->Open(VFSFlags::OF_Read) == 0);
            this_thread::sleep_for(5ms);
            auto d = file->ReadFile();
            XCTAssert(d);
            XCTAssert(d->size() > 0);
            XCTAssert(d->size() == st.size);
        });
    
    dispatch_group_wait(dg, DISPATCH_TIME_FOREVER);
}

// was fault before 1.0.6, so introducing this regression test
- (void)testAngular
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_Angular.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }

    XCTAssert( host->StatTotalFiles() == 2764 );
    XCTAssert( host->StatTotalRegs() == 2431 );
    XCTAssert( host->StatTotalDirs() == 333 );
    
    VFSStat st;
    auto fn = "/angular-1.4.0-beta.4/docs/examples/example-week-input-directive/protractor.js";
    XCTAssert( host->Stat(fn, st, 0, 0) == 0 );
    XCTAssert( st.mode_bits.reg );
    XCTAssert( st.size == 1207 );

    VFSFilePtr file;
    XCTAssert( host->CreateFile(fn, file, nullptr) == 0);
    XCTAssert( file->Open(VFSFlags::OF_Read) == 0);
    auto d = file->ReadFile();
    XCTAssert( d->size() == 1207 );
    auto ref = "var value = element(by.binding('example.value | date: \"yyyy-Www\"'));";
    XCTAssert( memcmp(d->data(), ref, strlen(ref)) == 0 );
}

// symlinks were faulty in <1.1.3
- (void)testXNU2
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_XNU2.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    VFSStat st;
    auto fn = "/xnu-3248.20.55/libkern/.clang-format";
    XCTAssert( host->Stat(fn, st, 0, 0) == 0 );
    XCTAssert( st.mode_bits.reg );
    XCTAssert( st.size == 957 );
    
    VFSFilePtr file;
    XCTAssert( host->CreateFile(fn, file, nullptr) == 0);
    XCTAssert( file->Open(VFSFlags::OF_Read) == 0);
    auto d = file->ReadFile();
    XCTAssert( d->size() == 957 );
    auto ref = "# See top level .clang-format for explanation of options";
    XCTAssert( memcmp(d->data(), ref, strlen(ref)) == 0 );
}

- (void)testEncrypted
{
    const auto passwd = "pass1"s;
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_Encrypted.c_str(), VFSNativeHost::SharedHost(), passwd);
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    XCTAssert( host->StatTotalFiles() == 2 );
    XCTAssert( host->StatTotalRegs() == 2 );
    XCTAssert( host->StatTotalDirs() == 0 );
    
    VFSFilePtr file;
    auto fn = "/file2";
    XCTAssert( host->CreateFile(fn, file, nullptr) == 0);
    XCTAssert( file->Open(VFSFlags::OF_Read) == 0);
    auto d = file->ReadFile();
    XCTAssert( d->size() == 19 );
    auto ref = "contents of file2.\0A";
    XCTAssert( memcmp(d->data(), ref, strlen(ref)) == 0 );
}

// contains symlinks
- (void)testAdiumZip
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_Adium.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    VFSStat st;
    XCTAssert( host->Stat("/Adium.app/Contents/Info.plist", st, 0, 0) == 0 );
    XCTAssert( st.mode_bits.reg );
    XCTAssert( st.size == 6201 );
    XCTAssert( host->Stat("/Adium.app/Contents/Info.plist", st, VFSFlags::F_NoFollow, 0) == 0 );
    XCTAssert( st.mode_bits.reg );
    XCTAssert( st.size == 6201 );
    
    XCTAssert( host->Stat("/Adium.app/Contents/Frameworks/Adium.framework/Adium", st, 0, 0) == 0 );
    XCTAssert( st.mode_bits.reg && !st.mode_bits.chr );
    XCTAssert( st.size == 2013068 );
    
    XCTAssert( host->Stat("/Adium.app/Contents/Frameworks/Adium.framework/Adium", st, VFSFlags::F_NoFollow, 0) == 0 );
    XCTAssert( st.mode_bits.reg && st.mode_bits.chr );
    
    XCTAssert( host->IsDirectory("/Adium.app/Contents/Frameworks/Adium.framework/Headers", 0, 0) == true );
    XCTAssert( host->IsSymlink  ("/Adium.app/Contents/Frameworks/Adium.framework/Headers", VFSFlags::F_NoFollow, 0) == true );
    
    char buf[MAXPATHLEN+1];
    XCTAssert( host->ReadSymlink("/Adium.app/Contents/Frameworks/Adium.framework/Adium", buf, MAXPATHLEN, 0) == 0 );
    XCTAssert( "Versions/Current/Adium"s == buf );
}

- (void)testAdiumZip_XAttrs
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_Adium.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }

    VFSFilePtr file;
    char buf[4096];
    ssize_t sz;
    
    // com.apple.quarantine has a special treating, value in archive differs from a plain value returned from xattr util
    XCTAssert( host->CreateFile("/Adium.app/Contents/MacOS/Adium", file, 0) == 0 );
    XCTAssert( file->Open( VFSFlags::OF_Read ) == 0 );
    XCTAssert( file->XAttrCount() == 1 );
    XCTAssert( (sz = file->XAttrGet("com.apple.quarantine", buf, sizeof(buf))) == 60 );
    XCTAssert( strncmp(buf, "q/0042;50f14fe0;Safari;9A8E9C25-2CA8-4A2C-8A45-852A966494A1", sz) == 0 );
    file.reset();
    
    XCTAssert( host->CreateFile("/Adium.app/Icon\r", file, 0) == 0 );
    XCTAssert( file->Open( VFSFlags::OF_Read ) == 0 );
    XCTAssert( file->XAttrCount() == 2 );
    XCTAssert( (sz = file->XAttrGet("com.apple.FinderInfo", buf, sizeof(buf))) == 32 );
    const uint8_t finfo[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                              0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    XCTAssert( memcmp(buf, finfo, sz) == 0 );
    file.reset();
}

- (void)testLZMASupport
{
  shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_LZMA.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }

    VFSFilePtr file;
    
    XCTAssert( host->CreateFile("/lzma-4.32.7/ltmain.sh", file, 0) == 0 );
    XCTAssert( file->Open( VFSFlags::OF_Read ) == 0 );

    auto d = file->ReadFile();
    XCTAssert( d->size() == 196440 );
    auto ref = "# ltmain.sh - Provide generalized library-building support services.";
    XCTAssert( memcmp(d->data(), ref, strlen(ref) ) == 0 );
    file.reset();
}

- (void)testArchiveWithWarning
{
  shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_WarningArchive.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }

    VFSFilePtr file;
    
    XCTAssert( host->CreateFile("/maverix-master/maverix-theme/app/js/app.js", file, 0) == 0 );
    XCTAssert( file->Open( VFSFlags::OF_Read ) == 0 );

    auto d = file->ReadFile();
    XCTAssert( d->size() == 1426 );
    auto ref = "'use strict';";
    XCTAssert( memcmp(d->data(), ref, strlen(ref) ) == 0 );
    file.reset();
}

- (void)testChineseArchive
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_ChineseArchive.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }

    VFSFilePtr file;
    
    XCTAssert( host->CreateFile(@"/操作系统原理/学生讲座/1.c".UTF8String, file, 0) == 0 );
    XCTAssert( file->Open( VFSFlags::OF_Read ) == 0 );

    auto d = file->ReadFile();
    XCTAssert( d->size() == 627 );
    auto ref = "#include <stdio.h>";
    XCTAssert( memcmp(d->data(), ref, strlen(ref) ) == 0 );
    file.reset();
}

- (void)testArchiveWithHeadingSlash
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_HeadingSlash.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    shared_ptr<VFSListing> listing;
    XCTAssert( host->FetchDirectoryListing("/", listing, 0, nullptr) == VFSError::Ok );
}

- (void)testArchiveWithSlashDir
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_SlashDir.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    shared_ptr<VFSListing> listing;
    XCTAssert( host->FetchDirectoryListing("/", listing, 0, nullptr) == VFSError::Ok );
}

- (void)testGDriveArchivesAreProperlyDecoded
{
    shared_ptr<ArchiveHost> host;
    try {
        host = make_shared<ArchiveHost>(g_GDriveDownload.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    VFSFilePtr file;    
    XCTAssert( host->CreateFile(@"/тест.txt".UTF8String, file, 0) == 0 );
    XCTAssert( file->Open( VFSFlags::OF_Read ) == 0 );
    
    auto d = file->ReadFile();
    XCTAssert( d->size() == 9 );
    auto ref = @"Тест!".UTF8String;
    XCTAssert( memcmp(d->data(), ref, strlen(ref) ) == 0 );
    file.reset();
    
}

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "info.filesmanager.files" ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

- (void) waitUntilFinish:(volatile bool&)_finished
{
    using namespace std::chrono;
    microseconds sleeped = 0us, sleep_tresh = 60s;
    while (!_finished)
    {
        this_thread::sleep_for(100us);
        sleeped += 100us;
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
}

@end
