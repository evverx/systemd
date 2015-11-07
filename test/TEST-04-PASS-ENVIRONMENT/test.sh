#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
TEST_DESCRIPTION="Test PassEnvironment Directive"

. $TEST_BASE_DIR/test-functions

test_run() {
    NSPAWN_ARGS="--setenv YOU_CAN_RESET_ME=MANAGER --setenv MANAGER_ONLY=MANAGER --setenv HIDES_CMDLINE=NSPAWN --setenv B=MANAGER --setenv C=MANAGER --setenv HIDES_CONFIG=NSPAWN $NSPAWN_ARGS"
    KERNEL_APPEND="systemd.setenv=HIDES_CMDLINE=CMDLINE systemd.setenv=YOU_CAN_NOT_RESET_ME=CMDLINE $KERNEL_APPEND"

    dwarn "skipping QEMU"

    if check_nspawn; then
        run_nspawn
        check_result_nspawn || return 1
    else
        dwarn "can't run systemd-nspawn, skipping"
    fi
    return 0
}

test_setup() {
    create_empty_image
    mkdir -p $TESTDIR/root
    mount ${LOOPDEV}p1 $TESTDIR/root

    # Create what will eventually be our root filesystem onto an overlay
    (
        LOG_LEVEL=5
        eval $(udevadm info --export --query=env --name=${LOOPDEV}p2)

        setup_basic_environment

        cat >>$initdir/etc/systemd/system.conf <<EOF
DefaultEnvironment=HIDES_CONFIG=CONFIG
EOF

        cat >$initdir/environment-file-for-test <<EOF
C=ENVIRONMENT_FILE
EOF

        cat >$initdir/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service
After=multi-user.target

[Service]
Type=oneshot
PassEnvironment=YOU_CAN_RESET_ME YOU_CAN_NOT_RESET_ME
PassEnvironment=
PassEnvironment=HIDES_CMDLINE UNKNOWN_VARIABLE HIDES_CONFIG
PassEnvironment=MANAGER_ONLY
PassEnvironment=MANAGER_ONLY MANAGER_ONLY
Environment=B=ENVIRONMENT
EnvironmentFile=/environment-file-for-test
ExecStart=/test-pass-environment.sh
EOF

        cp test-pass-environment.sh $initdir/

        setup_testsuite
    )
    setup_nspawn_root

    ddebug "umount $TESTDIR/root"
    umount $TESTDIR/root
}

test_cleanup() {
    umount $TESTDIR/root 2>/dev/null
    [[ $LOOPDEV ]] && losetup -d $LOOPDEV
    return 0
}

do_test "$@"
