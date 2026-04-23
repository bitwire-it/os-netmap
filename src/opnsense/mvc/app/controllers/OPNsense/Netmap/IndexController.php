<?php

/*
 * Copyright (C) 2026 os-netmap contributors
 * All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 */

namespace OPNsense\Netmap;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction(): void
    {
        $this->view->pick('OPNsense/Netmap/index');
    }
}
