#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int showFailure(NSString *message)
{
    fprintf(stderr, "%s\n", message.UTF8String);
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Nije moguće pokrenuti NFS II SE";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"U redu"];
    [alert runModal];
    return 1;
}

static BOOL migrateTextAssets(NSBundle *bundle, NSURL *seed, NSURL *gameData,
                              NSURL *support, NSError **error)
{
    NSFileManager *files = NSFileManager.defaultManager;
    NSURL *originals = [bundle.resourceURL URLByAppendingPathComponent:@"text-compat-originals"
                                                          isDirectory:YES];
    NSArray<NSURL *> *entries = [files contentsOfDirectoryAtURL:originals
                                   includingPropertiesForKeys:nil options:0 error:error];
    if (!entries)
        return NO;

    NSURL *bundledText = [seed URLByAppendingPathComponent:@"FEDATA/PC/TEXT" isDirectory:YES];
    NSURL *userText = [gameData URLByAppendingPathComponent:@"FEDATA/PC/TEXT" isDirectory:YES];
    NSURL *backupDirectory = nil;
    for (NSURL *original in entries) {
        NSDictionary<NSFileAttributeKey, id> *originalAttributes =
            [files attributesOfItemAtPath:original.path error:error];
        if (!originalAttributes)
            return NO;
        // Do not follow links or treat subdirectories as compatibility assets.
        if (![originalAttributes[NSFileType] isEqualToString:NSFileTypeRegular])
            continue;

        NSString *name = original.lastPathComponent;
        NSURL *corrected = [bundledText URLByAppendingPathComponent:name];
        NSDictionary<NSFileAttributeKey, id> *correctedAttributes =
            [files attributesOfItemAtPath:corrected.path error:error];
        if (!correctedAttributes)
            return NO;
        if (![correctedAttributes[NSFileType] isEqualToString:NSFileTypeRegular]) {
            if (error)
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError
                    userInfo:@{NSLocalizedDescriptionKey:
                        [@"Neispravan paket tekstualnih podataka: " stringByAppendingString:name]}];
            return NO;
        }
        NSData *originalData = [NSData dataWithContentsOfURL:original options:0 error:error];
        if (!originalData)
            return NO;
        NSData *correctedData = [NSData dataWithContentsOfURL:corrected options:0 error:error];
        if (!correctedData)
            return NO;

        NSURL *existing = [userText URLByAppendingPathComponent:name];
        NSError *lookupError = nil;
        NSDictionary<NSFileAttributeKey, id> *existingAttributes =
            [files attributesOfItemAtPath:existing.path error:&lookupError];
        if (!existingAttributes) {
            BOOL missing = [lookupError.domain isEqualToString:NSCocoaErrorDomain] &&
                (lookupError.code == NSFileReadNoSuchFileError ||
                 lookupError.code == NSFileNoSuchFileError);
            if (!missing) {
                if (error) *error = lookupError;
                return NO;
            }
            if (![files createDirectoryAtURL:userText withIntermediateDirectories:YES
                                  attributes:nil error:error] ||
                ![correctedData writeToURL:existing options:NSDataWritingAtomic error:error])
                return NO;
            fprintf(stderr, "Installed corrected text asset: %s (previously missing)\n", name.UTF8String);
            continue;
        }
        if (![existingAttributes[NSFileType] isEqualToString:NSFileTypeRegular]) {
            fprintf(stderr, "Preserved custom text asset: %s (not a regular file)\n", name.UTF8String);
            continue;
        }

        NSData *existingData = [NSData dataWithContentsOfURL:existing options:0 error:error];
        if (!existingData)
            return NO;
        if ([existingData isEqualToData:correctedData])
            continue;
        if (![existingData isEqualToData:originalData]) {
            fprintf(stderr, "Preserved custom text asset: %s (differs from bundled versions)\n",
                    name.UTF8String);
            continue;
        }

        if (!backupDirectory) {
            NSURL *backups = [support URLByAppendingPathComponent:@"asset-backups" isDirectory:YES];
            backupDirectory = [backups URLByAppendingPathComponent:NSUUID.UUID.UUIDString
                                                     isDirectory:YES];
            if (![files createDirectoryAtURL:backupDirectory withIntermediateDirectories:YES
                                  attributes:nil error:error])
                return NO;
        }
        NSURL *backup = [backupDirectory URLByAppendingPathComponent:name];
        if (![files copyItemAtURL:existing toURL:backup error:error] ||
            ![correctedData writeToURL:existing options:NSDataWritingAtomic error:error])
            return NO;
        fprintf(stderr, "Migrated text asset: %s; backup: %s\n",
                name.UTF8String, backup.fileSystemRepresentation);
    }
    return YES;
}

int main(void)
{
    @autoreleasepool {
        NSFileManager *files = NSFileManager.defaultManager;
        NSURL *userLibrary = [[files URLsForDirectory:NSLibraryDirectory
                                           inDomains:NSUserDomainMask] firstObject];
        NSURL *logs = [userLibrary URLByAppendingPathComponent:@"Logs/NFS II SE"
                                                   isDirectory:YES];
        NSError *error = nil;
        if (![files createDirectoryAtURL:logs withIntermediateDirectories:YES
                              attributes:nil error:&error])
            return showFailure(error.localizedDescription);

        NSURL *logFile = [logs URLByAppendingPathComponent:@"game.log"];
        if (!freopen(logFile.fileSystemRepresentation, "a", stdout) ||
            !freopen(logFile.fileSystemRepresentation, "a", stderr))
            return showFailure(@"Nije moguće otvoriti dnevnik igre u Library/Logs/NFS II SE.");
        setvbuf(stdout, NULL, _IOLBF, 0);
        setvbuf(stderr, NULL, _IONBF, 0);
        fprintf(stderr, "\n--- NFS II SE launch: %s ---\n", NSDate.date.description.UTF8String);

        NSBundle *bundle = NSBundle.mainBundle;
        NSURL *seed = [bundle.resourceURL URLByAppendingPathComponent:@"game-data"
                                                        isDirectory:YES];
        NSURL *binary = [[bundle.executableURL URLByDeletingLastPathComponent]
                         URLByAppendingPathComponent:@"nfs2se"];
        NSURL *support = [[files URLsForDirectory:NSApplicationSupportDirectory
                                        inDomains:NSUserDomainMask].firstObject
                          URLByAppendingPathComponent:@"NFS II SE" isDirectory:YES];
        NSURL *gameData = [support URLByAppendingPathComponent:@"game-data"
                                                  isDirectory:YES];

        if (![files isExecutableFileAtPath:binary.path])
            return showFailure(@"U aplikaciji nedostaje izvršni fajl igre. Ponovo napravi aplikaciju.");
        if (![files createDirectoryAtURL:support withIntermediateDirectories:YES
                              attributes:nil error:&error])
            return showFailure(error.localizedDescription);

        BOOL isDirectory = NO;
        if (![files fileExistsAtPath:gameData.path isDirectory:&isDirectory]) {
            NSURL *staging = [support URLByAppendingPathComponent:
                [@".game-data-" stringByAppendingString:NSUUID.UUID.UUIDString]
                                                    isDirectory:YES];
            if (![files copyItemAtURL:seed toURL:staging error:&error]) {
                [files removeItemAtURL:staging error:nil];
                return showFailure([@"Nije moguće pripremiti podatke igre: "
                                    stringByAppendingString:error.localizedDescription]);
            }
            if (![files moveItemAtURL:staging toURL:gameData error:&error]) {
                // Another launch may have completed the same atomic first-run setup.
                [files removeItemAtURL:staging error:nil];
                if (![files fileExistsAtPath:gameData.path isDirectory:&isDirectory] ||
                    !isDirectory)
                    return showFailure(error.localizedDescription);
            }
        } else if (!isDirectory) {
            return showFailure(@"Library/Application Support/NFS II SE/game-data mora da bude fascikla.");
        }

        // Repair the first package's missing CD/data marker without replacing
        // any existing user file. The original Windows executable is data only.
        NSURL *marker = [gameData URLByAppendingPathComponent:@"NFS2SEN.EXE"];
        if (![files fileExistsAtPath:marker.path]) {
            NSURL *seedMarker = [seed URLByAppendingPathComponent:@"NFS2SEN.EXE"];
            NSURL *temporary = [gameData URLByAppendingPathComponent:
                [@".NFS2SEN-" stringByAppendingString:NSUUID.UUID.UUIDString]];
            if (![files copyItemAtURL:seedMarker toURL:temporary error:&error])
                return showFailure(error.localizedDescription);
            // link() publishes a complete file atomically and never overwrites.
            int result = link(temporary.fileSystemRepresentation, marker.fileSystemRepresentation);
            int linkError = errno;
            [files removeItemAtURL:temporary error:nil];
            if (result != 0 && linkError != EEXIST)
                return showFailure([NSString stringWithFormat:@"Nije moguće pripremiti oznaku podataka igre: %s",
                                    strerror(linkError)]);
        }

        if (!migrateTextAssets(bundle, seed, gameData, support, &error))
            return showFailure([@"Nije moguće ažurirati tekstualne podatke igre: "
                                stringByAppendingString:error.localizedDescription]);

        if (chdir(gameData.fileSystemRepresentation) != 0)
            return showFailure([NSString stringWithFormat:@"Nije moguće otvoriti podatke igre: %s",
                                strerror(errno)]);

        fprintf(stderr, "Game data: %s\n", gameData.fileSystemRepresentation);
        const char *executablePath = binary.fileSystemRepresentation;
        const char *dataPath = gameData.fileSystemRepresentation;
        char *const arguments[] = {(char *)executablePath, (char *)dataPath, NULL};
        execv(executablePath, arguments);
        return showFailure([NSString stringWithFormat:@"Pokretanje igre nije uspelo: %s",
                            strerror(errno)]);
    }
}
