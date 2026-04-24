<?php

namespace Tests\Integration\Controllers;

use Core\Constants\Constants;
use Core\Http\Request;
use Core\Router\Router;
use Tests\TestCase;

abstract class ControllerTestCase extends TestCase
{
    private Request $request;

    public function setUp(): void
    {
        parent::setUp();
        Router::reset();
        require Constants::rootPath()->join('config/routes.php');

        $_SERVER['REQUEST_METHOD'] = 'GET';
        $_SERVER['REQUEST_URI'] = '/';
        $this->request = new Request();
    }

    public function tearDown(): void
    {
        unset($_SERVER['REQUEST_METHOD']);
        unset($_SERVER['REQUEST_URI']);
        unset($_SERVER['HTTP_ACCEPT']);
        unset($_SESSION['user']);
        Router::reset();
        parent::tearDown();
    }

    /**
     * @param array<string, mixed> $params
     */
    public function get(string $action, string $controllerName, array $params = []): string
    {
        return $this->execController($action, $controllerName, $params);
    }

    /**
     * @param array<string, mixed> $params
     */
    public function post(string $action, string $controllerName, array $params = []): string
    {
        return $this->execController($action, $controllerName, $params);
    }

    /**
     * @param array<string, mixed> $params
     */
    public function put(string $action, string $controllerName, array $params = []): string
    {
        return $this->execController($action, $controllerName, $params);
    }

    /**
     * @param array<string, mixed> $params
     */
    private function execController(string $action, string $controllerName, array $params = []): string
    {
        $controller = $this->getControllerInstance($controllerName);
        $this->request->addParams($params);

        ob_start();
        try {
            $controller->$action($this->request);
            return ob_get_contents();
        } catch (\Exception $e) {
            throw $e;
        } finally {
            ob_end_clean();
        }
    }

    /**
     * Creates a test controller instance with overridden redirect behavior
     * @template T of \Core\Http\Controllers\Controller
     * @param class-string<T> $controllerName
     * @return \Core\Http\Controllers\Controller
     */
    private function getControllerInstance(string $controllerName)
    {
        // Generate a unique class name by appending a random hash to avoid naming conflicts
        // when creating multiple test controller instances in the same test run
        $className = 'TestController' . md5(uniqid('', true));

        $code = "
            class {$className} extends {$controllerName} {
                protected function redirectTo(string \$location): void {
                    echo 'Location: ' . \$location;
                }
            }
        ";

        eval($code);

        return new $className();
    }
}
