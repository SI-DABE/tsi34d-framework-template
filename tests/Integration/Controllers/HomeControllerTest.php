<?php

namespace Tests\Integration\Controllers;

class HomeControllerTest extends ControllerTestCase
{
    public function test_render_home_page(): void
    {
        $response = $this->get(
            action: 'index',
            controllerName: 'App\Controllers\HomeController'
        );

        $this->assertMatchesRegularExpression('/<h1>\s*Home Page\s*<\/h1>/', $response);
        $this->assertMatchesRegularExpression('/TSI3D Framework Template/', $response);
    }
}
